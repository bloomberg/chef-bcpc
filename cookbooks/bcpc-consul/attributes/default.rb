default['bcpc-consul']['conf_dir'] = '/etc/consul/conf.d'
default['bcpc-consul']['data_dir'] = '/var/lib/consul'
default['bcpc-consul']['log_level'] = 'INFO'
default['bcpc-consul']['executable'] = '/usr/local/sbin/consul'
default['bcpc-consul']['username'] = 'consul'
default['bcpc-consul']['client_addr'] = '127.0.0.1'
default['bcpc-consul']['addresses']['dns'] =
  node['bcpc']['management']['vip']
default['bcpc-consul']['ports'] = {
  'dns' => 8600
}
default['bcpc-consul']['sudo'] = [
  '/usr/sbin/birdc',
  '/usr/local/bin/consul-dns-check',
  '/usr/local/bin/consul-haproxy-check'
]
