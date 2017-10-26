# Service definitions reference:
# https://www.consul.io/docs/agent/services.html
default['bcpc-consul']['services'] = [
  {
    'name' => 'mysql',
    'port' => 3306,
    'enable_tag_override' => true,
    'tags' => ['mysql'],
    'check' => {
      'name' => 'mysql',
      'args' => ['/usr/local/bin/consul-mysql-check'],
      'interval' => '10s',
      'timeout' => '2s'
    }
  },
  {
    'name' => 'haproxy',
    'check' => {
      'name' => 'haproxy',
      'args' => ['sudo', '/usr/local/bin/consul-haproxy-check'],
      'interval' => '10s',
      'timeout' => '2s'
    }
  },
  {
    'name' => 'dns',
    'check' => {
      'name' => 'dns',
      'args' => ['sudo', '/usr/local/bin/consul-dns-check'],
      'interval' => '10s',
      'timeout' => '2s'
    }
  },
  {
    'name' => 'dns',
    'check' => {
      'name' => 'dns',
      'args' => ['sudo', '/usr/local/bin/consul-dns-check'],
      'interval' => '10s',
      'timeout' => '2s'
    }
  }
]
