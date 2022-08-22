#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o nounset
set -o pipefail
set -o xtrace
set -o errexit

# install_dependencies() - Install required dependencies
function install_dependencies {
    sudo apt-get update
    sudo apt-get install -y -qq wget openjdk-8-jre bridge-utils net-tools bsdmainutils
}

# install_vpp() - Install VPP
function install_vpp {
    sudo apt-get update
    sudo apt-get install -y -qq apt-transport-https

    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    echo "deb [trusted=yes] https://packagecloud.io/fdio/release/ubuntu $VERSION_CODENAME main" | sudo tee /etc/apt/sources.list.d/99fd.io.list
    curl -L https://packagecloud.io/fdio/release/gpgkey | sudo apt-key add -
    sudo apt-get update
    sudo apt-get install -y -qq vpp vpp-plugin-core vpp-plugin-dpdk
}

function _untar_url {
    local repo_url="https://nexus.onap.org/content/repositories/releases/org/onap/demo/vnf/"
    local file_subpath=$1

    wget -q -O tmp_file.tar.gz "${repo_url}/${file_subpath}"
    sha1=$(wget "${repo_url}/${file_subpath}.sha1" -q -O -)
    if [[ $(sha1sum tmp_file.tar.gz  | awk '{print $1}') != "$sha1" ]]; then
        echo "The downloaded file is corrupted"
        exit 1
    fi
    tar -zmxf tmp_file.tar.gz
    rm tmp_file.tar.gz
}

# install_vfw_scripts() -
function install_vfw_scripts {
    version=$(cat /opt/config/demo_artifacts_version.txt)

    pushd /opt
    wget -q https://git.onap.org/demo/plain/vnfs/vFW/scripts/{v_packetgen_init,vpacketgen,run_traffic_fw_demo}.sh
    chmod +x ./*.sh

    _untar_url "sample-distribution/${version}/sample-distribution-${version}-hc.tar.gz"
    mv "sample-distribution-$version" honeycomb

    _untar_url "vfw/vfw_pg_streams/$version/vfw_pg_streams-$version-demo.tar.gz"
    mv "vfw_pg_streams-$version" pg_streams

    sed -i 's/"restconf-binding-address": "127.0.0.1",/"restconf-binding-address": "0.0.0.0",/g' /opt/honeycomb/config/honeycomb.json

    # TODO(electrocucaracha) Fix it in upstream
    sed -i 's/start vpp/systemctl start vpp/g' v_packetgen_init.sh
    sed -i "s|/opt/honeycomb/sample-distribution-\$VERSION/honeycomb|/opt/honeycomb/honeycomb|g" v_packetgen_init.sh
    mv vpacketgen.sh /etc/init.d/
    update-rc.d vpacketgen.sh defaults
    systemctl start packetgen
    popd
}

mkdir -p /opt/config/
echo "${protected_net_cidr:-192.168.20.0/24}" > /opt/config/protected_net_cidr.txt
echo "${vfw_private_ip_0:-192.168.10.100}" > /opt/config/fw_ipaddr.txt
echo "${vsn_private_ip_0:-192.168.20.250}" > /opt/config/sink_ipaddr.txt
echo "${demo_artifacts_version:-1.6.0}" > /opt/config/demo_artifacts_version.txt

echo 'vm.nr_hugepages = 1024' >> /etc/sysctl.conf
sysctl -p

install_dependencies
install_vpp
install_vfw_scripts
