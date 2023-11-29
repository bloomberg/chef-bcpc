###############################################################################
# keystone
###############################################################################

# specify database and configure SQLAlchemy overflow/QueuePool sizes
default['bcpc']['keystone']['db']['dbname'] = 'keystone'
default['bcpc']['keystone']['db']['max_overflow'] = 128
default['bcpc']['keystone']['db']['max_pool_size'] = 64

# caching
default['bcpc']['keystone']['enable_caching'] = true

# default log file
default['bcpc']['keystone']['log_file'] = '/var/log/keystone/keystone.log'

# enable debug logging (also caching debug logging).
default['bcpc']['keystone']['debug'] = false

# Set the number of Keystone WSGI processes
default['bcpc']['keystone']['workers'] = nil

# Notifications driver
default['bcpc']['keystone']['drivers']['notification'] = 'log'
default['bcpc']['keystone']['notification_format'] = 'cadf'

# Identity configuration
# Understand the implications: https://docs.openstack.org/developer/keystone/configuration.html#domain-specific-drivers
default['bcpc']['keystone']['identity']['domain_configurations_from_database'] = true

default['bcpc']['keystone']['roles']['admin'] = 'admin'
default['bcpc']['keystone']['roles']['member'] = 'member'

default['bcpc']['keystone']['admin']['email'] = "admin@#{node['bcpc']['cloud']['domain']}"
default['bcpc']['keystone']['admin']['username'] = 'admin'
default['bcpc']['keystone']['admin']['project_name'] = 'admin'
default['bcpc']['keystone']['admin']['domain'] = 'default'
default['bcpc']['keystone']['admin']['enable_admin_project'] = true

default['bcpc']['keystone']['service_project']['name'] = 'service'
default['bcpc']['keystone']['service_project']['domain'] = 'default'

default['bcpc']['keystone']['default_domain'] = 'default'

# LDAP credentials used by Keystone
default['bcpc']['ldap']['admin_user'] = nil
default['bcpc']['ldap']['admin_pass'] = nil
default['bcpc']['ldap']['admin_user_domain'] = nil
default['bcpc']['ldap']['admin_project_domain'] = nil
default['bcpc']['ldap']['admin_project_name'] = nil
default['bcpc']['ldap']['config'] = {}

# Domain configs
# <Name> => { description => {}, config => {} }
default['bcpc']['keystone']['domain_config_dir'] = '/etc/keystone/domains'
default['bcpc']['keystone']['domains'] = {}
