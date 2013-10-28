###########################################
#
#  Configuration for quantum
#
###########################################

default['bcpc']['quantum']['core_plugin'] = "quantum.plugins.linuxbridge.lb_quantum_plugin.LinuxBridgePluginV2"
default['bcpc']['quantum']['bind_host'] = "0.0.0.0"
default['bcpc']['quantum']['bind_port'] = "9696"
default['bcpc']['quantum']['rpc_backend'] = "quantum.openstack.common.rpc.impl_kombu"
default['bcpc']['quantum']['plugin_config'] = "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini"
default['bcpc']['quantum']['firewall_driver'] = "nova.virt.firewall.NoopFirewallDriver"
default['bcpc']['quantum']['compute_driver'] = "libvirt.LibvirtDriver"
default['bcpc']['quantum']['metadata_proxy'] = "True"
default['bcpc']['quantum']['auth_strategy'] = "keystone"
default['bcpc']['quantum']['network_api_class'] = "nova.network.quantumv2.api.API"
default['bcpc']['quantum']['libvirt_vif_driver'] = "nova.virt.libvirt.vif.LibvirtGenericVIFDriver"
default['bcpc']['quantum']['security_group_api'] = "quantum"
default['bcpc']['quantum']['root_helper'] = "sudo /usr/bin/quantum-rootwrap /etc/quantum/rootwrap.conf"
default['bcpc']['quantum']['verbose'] = "False"
default['bcpc']['quantum']['debug'] = "False"
default['bcpc']['quantum']['signing_dir'] = "/var/cache/quantum"
default['bcpc']['quantum']['state_path'] = "/var/lib/quantum"
# VLAN range start
default['bcpc']['lb']['vlan_start'] = "800"
# VLAN range end
default['bcpc']['lb']['vlan_end'] = "900"

