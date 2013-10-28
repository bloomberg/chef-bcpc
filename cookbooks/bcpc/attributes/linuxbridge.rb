###########################################
#
#  Configuration for linuxbridge plugin
#
###########################################
# Name of the physical interface 
default['bcpc']['lb']['physical'] = "physnet1"
# VLAN range start
default['bcpc']['lb']['vlan_start'] = "1000"
# VLAN range end
default['bcpc']['lb']['vlan_end'] = "1100"
# Firewall driver
default['bcpc']['lb']['firewall_driver'] = "quantum.agent.linux.iptables_firewall.IptablesFirewallDriver"
# DHCP: interface driver
default['bcpc']['lb']['interface_driver'] = "quantum.agent.linux.interface.BridgeInterfaceDriver"
# DHCP: dhcp driver
default['bcpc']['lb']['dhcp_driver'] = "quantum.agent.linux.dhcp.Dnsmasq"
# DHCP: dhcp config file
default['bcpc']['lb']['dhcp_config'] = "/etc/quantum/dnsmasq.conf"

