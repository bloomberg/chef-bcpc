###############################################################################
# rally
###############################################################################

user = 'rally'
group = 'rally'
home_dir = "/home/#{user}"
install_dir = "#{home_dir}/rally"
venv_dir = "#{install_dir}/venv"
database_dir = "#{venv_dir}/database"
conf_dir = "#{venv_dir}/etc/rally"

default['bcpc']['rally']['enabled'] = false
default['bcpc']['rally']['version'] = '1.3.0'
default['bcpc']['rally']['ssl_verify'] = false
default['bcpc']['rally']['user'] = user
default['bcpc']['rally']['group'] = group
default['bcpc']['rally']['home_dir'] = home_dir
default['bcpc']['rally']['install_dir'] = install_dir
default['bcpc']['rally']['venv_dir'] = venv_dir
default['bcpc']['rally']['conf_dir'] = conf_dir
default['bcpc']['rally']['database_dir'] = database_dir
default['bcpc']['rally']['keystone']['version'] = 'v3'
