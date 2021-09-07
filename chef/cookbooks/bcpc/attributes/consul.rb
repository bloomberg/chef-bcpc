###############################################################################
# consul
###############################################################################

default['bcpc']['consul']['remote_file'] = {
  'file' => 'consul_1.7.2_linux_amd64.zip',
  'checksum' => '5ab689cad175c08a226a5c41d16392bc7dd30ceaaf90788411542a756773e698',
}

default['bcpc']['consul']['executable'] = '/usr/local/sbin/consul'
default['bcpc']['consul']['conf_dir'] = '/etc/consul/conf.d'
default['bcpc']['consul']['config']['datacenter'] = node.chef_environment
default['bcpc']['consul']['config']['client_addr'] = '127.0.0.1'
default['bcpc']['consul']['config']['advertise_addr'] = node['service_ip']
default['bcpc']['consul']['config']['data_dir'] = '/var/lib/consul'
default['bcpc']['consul']['config']['disable_update_check'] = true
default['bcpc']['consul']['config']['enable_script_checks'] = true
default['bcpc']['consul']['config']['server'] = true
default['bcpc']['consul']['config']['log_level'] = 'INFO'
default['bcpc']['consul']['config']['node_name'] = node['hostname']
default['bcpc']['consul']['config']['addresses']['dns'] = node['bcpc']['cloud']['vip']
default['bcpc']['consul']['config']['ports']['dns'] = 8600
default['bcpc']['consul']['config']['recursors'] = [node['bcpc']['cloud']['vip']]

# Load the MySQL and ProxySQL attribute files in order to populate both
# service's port attributes. Chef attribute files are loaded alphabetically,
# thus the need for an explicit load.
# NOTE: In order to more easily switch between a ProxySQL-enabled installation
# and one where MySQL is used directly, the ProxySQL service is defined in
# consul regardless of whether or not it is enabled. The ProxySQL consul service
# will only be available when ProxySQL is enabled.
node.from_file(run_context.resolve_attribute('bcpc', 'mysql'))
node.from_file(run_context.resolve_attribute('bcpc', 'proxysql'))

# Service definitions reference:
# https://www.consul.io/docs/agent/services.html
default['bcpc']['consul']['services'] = [
  {
    'name' => 'mysql',
    'port' => node['bcpc']['mysql']['port'],
    'enable_tag_override' => true,
    'tags' => ['mysql'],
    'check' => {
      'name' => 'mysql',
      'args' => ['/usr/local/bcpc/bin/mysql-check'],
      'interval' => '10s',
      'timeout' => '2s',
    },
  },
  {
    'name' => 'proxysql',
    'port' => node['bcpc']['proxysql']['port'],
    'enable_tag_override' => true,
    'tags' => ['proxysql'],
    'check' => {
      'name' => 'proxysql',
      'args' => ['/usr/local/bcpc/bin/proxysql-check'],
      'interval' => '10s',
      'timeout' => '2s',
    },
  },
  {
    'name' => 'haproxy',
    'check' => {
      'name' => 'haproxy',
      'args' => ['/usr/local/bcpc/bin/haproxy-check'],
      'interval' => '10s',
      'timeout' => '2s',
    },
  },
  {
    'name' => 'dns',
    'check' => {
      'name' => 'dns',
      'args' => ['/usr/local/bcpc/bin/dns-check'],
      'interval' => '10s',
      'timeout' => '2s',
    },
  },
]

# Watch definitions reference:
# https://www.consul.io/docs/agent/watches.html
default['bcpc']['consul']['watches'] = [
  {
    'service' => 'haproxy',
    'type' => 'checks',
    'args' => ['/usr/local/bcpc/bin/cloud-ip-watch', 'haproxy'],
  },
  {
    'service' => 'mysql',
    'type' => 'checks',
    'args' => ['/usr/local/bcpc/bin/service-elect-watch', 'mysql'],
  },
  {
    'service' => 'mysql',
    'type' => 'checks',
    'args' => ['/usr/local/bcpc/bin/service-watch', 'mysql'],
  },
  {
    'service' => 'proxysql',
    'type' => 'checks',
    'args' => ['/usr/local/bcpc/bin/service-elect-watch', 'proxysql'],
  },
  {
    'service' => 'proxysql',
    'type' => 'checks',
    'args' => ['/usr/local/bcpc/bin/service-watch', 'proxysql'],
  },
  {
    'service' => 'dns',
    'type' => 'checks',
    'args' => ['/usr/local/bcpc/bin/cloud-ip-watch', 'dns'],
  },
]
