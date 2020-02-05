###############################################################################
# rally
###############################################################################

default['bcpc']['rally']['enabled'] = true
default['bcpc']['rally']['rally_openstack']['version'] = '1.6.0'
default['bcpc']['rally']['rally']['version'] = '1.6.0'
default['bcpc']['rally']['ssl_verify'] = false
default['bcpc']['rally']['conf_dir'] = '/etc/rally'
default['bcpc']['rally']['home_dir'] = '/var/lib/rally'
default['bcpc']['rally']['venv_dir'] = '/usr/local/lib/rally'
default['bcpc']['rally']['database_dir'] = '/var/lib/rally/db'
