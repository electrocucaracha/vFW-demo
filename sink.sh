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
    sudo apt install -y wget darkstat net-tools

    # Configure and run Darkstat
    sed -i "s/START_DARKSTAT=.*/START_DARKSTAT=yes/g;s/INTERFACE=.*/INTERFACE=\"-i eth1\"/g" /etc/darkstat/init.cfg

    systemctl restart darkstat
}

# install_vfw_scripts() -
function install_vfw_scripts {
    pushd /opt
    wget -q https://git.onap.org/demo/plain/vnfs/vFW/scripts/{v_sink_init,vsink}.sh
    chmod +x ./*.sh

    mv vsink.sh /etc/init.d
    update-rc.d vsink.sh defaults
    systemctl start sink
    popd
}

mkdir -p /opt/config/
echo "${protected_net_cidr:-192.168.20.0/24}" > /opt/config/protected_net_cidr.txt
echo "${vfw_private_ip_0:-192.168.10.100}" > /opt/config/fw_ipaddr.txt
echo "${vsn_private_ip_0:-192.168.20.250}" > /opt/config/sink_ipaddr.txt
echo "${demo_artifacts_version:-1.6.0}" > /opt/config/demo_artifacts_version.txt
echo "${protected_net_gw:-192.168.20.100}" > /opt/config/protected_net_gw.txt
echo "${protected_private_net_cidr:-192.168.10.0/24}" > /opt/config/unprotected_net.txt

install_dependencies
install_vfw_scripts
