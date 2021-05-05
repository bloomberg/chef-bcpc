###############################################################################
# cloud
###############################################################################

default['bcpc']['cloud']['region'] = node.chef_environment

###############################################################################
# file server
###############################################################################

default['bcpc']['web_server']['url'] = 'http://bootstrap:8080/files/'

###############################################################################
# local_proxy
###############################################################################

default['bcpc']['local_proxy']['enabled'] = false
default['bcpc']['local_proxy']['config']['listen'] = '127.0.0.1'
default['bcpc']['local_proxy']['config']['port'] = '8888'

###############################################################################
# libvirt
###############################################################################

# ulimits for libvirt-bin
default['bcpc']['libvirt-bin']['ulimit']['nofile'] = 4096

###############################################################################
# misc settings
###############################################################################

# debugging process crashes
default['bcpc']['apport']['enabled'] = true

# enable/disable trusted platform module
default['bcpc']['tpm']['enabled'] = true

# enable/disable feed random data from hardware to kernel
default['bcpc']['hwrng']['enabled'] = true
default['bcpc']['hwrng']['source'] = nil

# enable/disable local firewall on hypervisor
default['bcpc']['host_firewall']['enabled'] = true

# list of extra TCP ports that should be open on the management interface
# (generally stuff served via HAProxy)
# some ports are hardcoded - see bcpc-firewall.erb template
default['bcpc']['management']['firewall_tcp_ports'] = [
  8088, 7480, 35357, 8004, 8000
]

# used for SOL (serial over lan) communication
default['bcpc']['getty']['ttys'] = %w(ttyS0 ttyS1)

# enable power-saving CPU scaling governor
default['bcpc']['hardware']['powersave']['enabled'] = false

###############################################################################
# horizon
###############################################################################

default['bcpc']['horizon']['disable_panels'] = ['containers']

###############################################################################
# metadata settings
###############################################################################

default['bcpc']['metadata']['vendordata']['enabled'] = false
# default['bcpc']['metadata']['vendordata']['driver'] = "nova.api.metadata.bcpc_metadata.BcpcMetadata"

###############################################################################
# virtualbox
###############################################################################

default['bcpc']['virtualbox']['nat_ip'] = '10.0.2.15'
