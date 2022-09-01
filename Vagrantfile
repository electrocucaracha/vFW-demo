# frozen_string_literal: true

# -*- mode: ruby -*-
# vi: set ft=ruby :
##############################################################################
# Copyright (c)
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

host = RbConfig::CONFIG['host_os']

vars = {
  'demo_artifacts_version' => '1.6.0',
  'vfw_private_ip_0' => '192.168.10.100',
  'vfw_private_ip_1' => '192.168.20.100',
  'vfw_private_ip_2' => '10.10.100.2',
  'vpg_private_ip_0' => '192.168.10.200',
  'vpg_private_ip_1' => '10.0.100.3',
  'vsn_private_ip_0' => '192.168.20.250',
  'vsn_private_ip_1' => '10.10.100.4',
  'dcae_collector_ip' => '10.0.4.1',
  'dcae_collector_port' => '8081',
  'protected_net_gw' => '192.168.20.100',
  'protected_net_cidr' => '192.168.20.0/24',
  'protected_private_net_cidr' => '192.168.10.0/24',
  'onap_private_net_cidr' => '10.10.0.0/16'
}

case host
when /darwin/
  mem = `sysctl -n hw.memsize`.to_i / 1024
when /linux/
  mem = `grep 'MemTotal' /proc/meminfo | sed -e 's/MemTotal://' -e 's/ kB//'`.to_i
when /mswin|mingw|cygwin/
  mem = `wmic computersystem Get TotalPhysicalMemory`.split[1].to_i / 1024
end

if !ENV['no_proxy'].nil? || ENV['NO_PROXY']
  no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || '127.0.0.1,localhost'
  subnet = '192.168.121'
  # NOTE: This range is based on vagrant-libivirt network definition
  (1..27).each do |i|
    no_proxy += ",#{subnet}.#{i}"
  end
end

# rubocop:disable Metrics/BlockLength
Vagrant.configure('2') do |config|
  # rubocop:enable Metrics/BlockLength
  config.vm.provider :libvirt
  config.vm.provider :virtualbox

  config.vm.box = 'generic/ubuntu1804'
  config.vm.box_check_update = false

  if !ENV['http_proxy'].nil? && !ENV['https_proxy'].nil?
    unless Vagrant.has_plugin?('vagrant-proxyconf')
      system 'vagrant plugin install vagrant-proxyconf'
      raise 'vagrant-proxyconf was installed but it requires to execute again'
    end
    config.proxy.http     = ENV['http_proxy'] || ENV['HTTP_PROXY'] || ''
    config.proxy.https    = ENV['https_proxy'] || ENV['HTTPS_PROXY'] || ''
    config.proxy.no_proxy = no_proxy
  end

  %i[virtualbox libvirt].each do |provider|
    config.vm.provider provider do |p|
      p.cpus = ENV['CPUS'] || 2
      p.memory = ENV['MEMORY'] || mem / 1024 / 4
    end
  end

  config.vm.provider 'virtualbox' do |v|
    v.gui = false
    v.customize ['modifyvm', :id, '--nictype1', 'virtio', '--cableconnected1', 'on']
    # https://bugs.launchpad.net/cloud-images/+bug/1829625/comments/2
    v.customize ['modifyvm', :id, '--uart1', '0x3F8', '4']
    v.customize ['modifyvm', :id, '--uartmode1', 'file', File::NULL]
    # Enable nested paging for memory management in hardware
    v.customize ['modifyvm', :id, '--nestedpaging', 'on']
    # Use large pages to reduce Translation Lookaside Buffers usage
    v.customize ['modifyvm', :id, '--largepages', 'on']
    # Use virtual processor identifiers  to accelerate context switching
    v.customize ['modifyvm', :id, '--vtxvpid', 'on']
  end

  config.vm.provider :libvirt do |v, _override|
    v.random_hostname = true
    v.management_network_address = '10.0.2.0/24'
    v.management_network_name = 'administration'
    v.cpu_mode = 'host-passthrough' # DPDK requires Supplemental Streaming SIMD Extensions 3 (SSSE3)
  end

  config.vm.define :packetgen do |packetgen|
    packetgen.vm.hostname = 'packetgen'
    packetgen.vm.provision 'shell', path: 'packetgen.sh', env: vars
    # unprotected_private_net_cidr
    packetgen.vm.network :private_network, ip: vars['vpg_private_ip_0'], type: :static,
                                           netmask: '255.255.255.0'
    # onap_private_net_cidr
    packetgen.vm.network :private_network, ip: vars['vpg_private_ip_1'], type: :static, netmask: '255.255.0.0'
    packetgen.trigger.after :up do |trigger|
      trigger.info = 'Wait for starting packetgen service:'
      trigger.run_remote = { inline: 'sleep 10' }
    end
    packetgen.trigger.after :up do |trigger|
      trigger.info = 'Packet Generator log messages:'
      trigger.run_remote = { inline: 'cat /var/log/vpacketgen.sh.log' }
    end
    packetgen.trigger.after :up do |trigger|
      trigger.info = 'Packet Generator error messages:'
      trigger.run_remote = { inline: 'cat /var/log/vpacketgen.sh.err' }
    end
  end
  config.vm.define :firewall do |firewall|
    firewall.vm.hostname = 'firewall'
    firewall.vm.provision 'shell', path: 'firewall.sh', env: vars
    # unprotected_private_net_cidr
    firewall.vm.network :private_network, ip: vars['vfw_private_ip_0'], type: :static, netmask: '255.255.255.0'
    # protected_private_net_cidr
    firewall.vm.network :private_network, ip: vars['vfw_private_ip_1'], type: :static, netmask: '255.255.255.0'
    # onap_private_net_cidr
    firewall.vm.network :private_network, ip: vars['vfw_private_ip_2'], type: :static, netmask: '255.255.0.0'
    firewall.trigger.after :up do |trigger|
      trigger.info = 'Wait for starting firewall service:'
      trigger.run_remote = { inline: 'sleep 10' }
    end
    firewall.trigger.after :up do |trigger|
      trigger.info = 'Firewall log messages:'
      trigger.run_remote = { inline: 'sudo cat /var/log/vfirewall.sh.log' }
    end
    firewall.trigger.after :up do |trigger|
      trigger.info = 'Firewall error messages:'
      trigger.run_remote = { inline: 'sudo cat /var/log/vfirewall.sh.err' }
    end
  end
  config.vm.define :sink do |sink|
    sink.vm.hostname = 'sink'
    sink.vm.provision 'shell', path: 'sink.sh', env: vars
    # protected_private_net_cidr
    sink.vm.network :private_network, ip: vars['vsn_private_ip_0'], type: :static, netmask: '255.255.255.0'
    # onap_private_net_cidr
    sink.vm.network :private_network, ip: vars['vsn_private_ip_1'], type: :static, netmask: '255.255.0.0'
    sink.trigger.after :up do |trigger|
      trigger.info = 'Wait for starting sink service:'
      trigger.run_remote = { inline: 'sleep 10' }
    end
    sink.trigger.after :up do |trigger|
      trigger.info = 'Sink log messages:'
      trigger.run_remote = { inline: 'sudo cat /var/log/vsink.sh.log' }
    end
    sink.trigger.after :up do |trigger|
      trigger.info = 'Sink error messages:'
      trigger.run_remote = { inline: 'sudo cat /var/log/vsink.sh.err' }
    end
  end
end
