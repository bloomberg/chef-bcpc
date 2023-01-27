###############################################################################
# rally
###############################################################################

default['bcpc']['rally']['enabled'] = false
default['bcpc']['rally']['rally']['version'] = '3.3.0'
default['bcpc']['rally']['rally_openstack']['version'] = '2.2.0'
default['bcpc']['rally']['tempest']['version'] = '30.0.0'
default['bcpc']['rally']['ssl_verify'] = false
default['bcpc']['rally']['conf_dir'] = '/etc/rally'
default['bcpc']['rally']['home_dir'] = '/var/lib/rally'
default['bcpc']['rally']['venv_dir'] = '/usr/local/lib/rally'
default['bcpc']['rally']['database_dir'] = '/var/lib/rally/db'
