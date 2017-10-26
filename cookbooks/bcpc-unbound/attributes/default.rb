default['bcpc-unbound']['server'] = {
  'access-control' => '0.0.0.0/0 allow',
  'chroot' => '""',
  'directory' => '/etc/unbound',
  'do-ip4' => 'yes',
  'do-udp' => 'yes',
  'do-tcp' => 'yes',
  'domain-insecure' => '*',
  'interface' => node['bcpc']['management']['vip'],
  'logfile' => '""',
  'num-threads' => 2,
  'pidfile' => '/var/run/unbound.pid',
  'port' => 53,
  'use-syslog' => 'yes',
  'verbosity' => 1
}
default['bcpc-unbound']['config_subdir'] =
  node['bcpc-unbound']['server']['directory'] + '/unbound.conf.d'
default['bcpc-unbound']['forward-zone'] = {
  'consul' => node['bcpc']['management']['vip'] + '@8600',
  node['bcpc']['domain_name'] => node['bcpc']['anycast']['pdns']['ip'] + '@53',
  '.' => node['bcpc']['dns_servers'][0]
}
default['bcpc-unbound']['data_dir'] = '/var/lib/unbound'
default['bcpc-unbound']['username'] = 'unbound'
default['bcpc-unbound']['groupname'] = 'unbound'
default['bcpc-unbound']['defaults']['root_trust_anchor_update'] = false
