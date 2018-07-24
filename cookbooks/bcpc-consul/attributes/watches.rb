# Watch definitions reference:
# https://www.consul.io/docs/agent/watches.html
default['bcpc-consul']['watches'] = [
  {
    'service' => 'haproxy',
    'type' => 'checks',
    'args' => ['/usr/local/bin/consul-haproxy-check-handler-watch']
  },
  {
    'service' => 'mysql',
    'type' => 'checks',
    'args' => ['/usr/local/bin/consul-mysql-leader-elect-watch']
  },
  {
    'service' => 'mysql',
    'type' => 'checks',
    'args' => ['/usr/local/bin/consul-mysql-check-handler-watch']
  },
  {
    'service' => 'dns',
    'type' => 'checks',
    'args' => ['/usr/local/bin/consul-dns-check-handler-watch']
  }
]
