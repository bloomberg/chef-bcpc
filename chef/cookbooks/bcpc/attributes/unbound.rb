###############################################################################
# unbound
###############################################################################

vip = node['bcpc']['cloud']['vip']
cloud_domain = node['bcpc']['cloud']['domain']
powerdns_address = node['bcpc']['powerdns']['local_address']
powerdns_port = node['bcpc']['powerdns']['local_port']

default['bcpc']['unbound']['default']['root_trust_anchor_update'] = false
default['bcpc']['unbound']['server']['access-control'] = '0.0.0.0/0 allow'
default['bcpc']['unbound']['server']['chroot'] = '""'
default['bcpc']['unbound']['server']['directory'] = '/etc/unbound'
default['bcpc']['unbound']['server']['do-ip4'] = 'yes'
default['bcpc']['unbound']['server']['do-ip6'] = 'no'
default['bcpc']['unbound']['server']['do-tcp'] = 'yes'
default['bcpc']['unbound']['server']['do-udp'] = 'yes'
default['bcpc']['unbound']['server']['domain-insecure'] = '*'
default['bcpc']['unbound']['server']['interface'] = vip
default['bcpc']['unbound']['server']['logfile'] = '""'
default['bcpc']['unbound']['server']['num-threads'] = 2
default['bcpc']['unbound']['server']['pidfile'] = '/var/run/unbound.pid'
default['bcpc']['unbound']['server']['port'] = 53
default['bcpc']['unbound']['server']['unblock-lan-zones'] = 'no'
default['bcpc']['unbound']['server']['use-syslog'] = 'yes'
default['bcpc']['unbound']['server']['verbosity'] = 1

# TLD quieries to forward to other name servers
#
default['bcpc']['unbound']['forward-zone']['consul'] = [vip + '@8600']
default['bcpc']['unbound']['forward-zone'][cloud_domain] = ["#{powerdns_address}@#{powerdns_port}"]
default['bcpc']['unbound']['forward-zone']['.'] = node['bcpc']['dns']['servers']
