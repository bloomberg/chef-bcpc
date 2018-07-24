#
# Cookbook Name:: bcpc
# Recipe:: nova-head
#
# Copyright 2018, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'openssl'
require 'net/ssh'

mysql_root_user     = get_config('mysql-root-user')
mysql_root_password = get_config('mysql-root-password')

nova_db = node['bcpc']['dbname']['nova']
nova_api_db = node['bcpc']['dbname']['nova_api']
nova_db_user = make_config('nova-db-user', "nova")
nova_db_password = make_config('nova-db-password', secure_password())

key = OpenSSL::PKey::RSA.new 2048;
pubkey = "#{key.ssh_type} #{[key.to_blob].pack('m0')}"
make_config('ssh-nova-private-key', key.to_pem)
make_config('ssh-nova-public-key', pubkey)

# nova and neutron have a cross dependancy that requires neutron to know
# about nova and vice versa in their configuration files so we need this
# information available for template generation to succeed
#
nova_os_user = make_config('nova-os-user', "nova")
nova_os_password = make_config('nova-os-password', secure_password())

neutron_os_user = make_config('neutron-os-user', "neutron")
neutron_os_password = make_config('neutron-os-password', secure_password())

placement_os_user = make_config('placement-os-user', "placement")
placement_os_password = make_config('placement-os-password', secure_password())

region          = node['bcpc']['region_name']
admin_role      = node['bcpc']['keystone']['admin_role']
service_project = node['bcpc']['keystone']['service_project']['name']
service_domain  = node['bcpc']['keystone']['service_project']['domain']


# create nova user starts
#
execute 'create openstack nova user' do
  environment (os_adminrc())

  command <<-EOH
    openstack user create \
      --domain #{service_domain} \
      --password #{nova_os_password} \
      #{nova_os_user}
  EOH

  not_if "openstack user show \
    --domain #{service_domain} #{nova_os_user}
  "
end

execute 'add admin role to nova user' do
  environment (os_adminrc())

  command <<-EOH
    openstack role add \
      --project #{service_project} \
      --user #{nova_os_user} \
      #{admin_role}
  EOH

  not_if "
    openstack role assignment list \
      --names \
      --role #{admin_role} \
      --project #{service_project} \
      --user #{nova_os_user} | grep #{nova_os_user}
  "
end
#
# create nova user ends


# create compute service and endpoints starts
#
begin
  type = 'compute'
  service = node['bcpc']['catalog'][type]
  project = service['project']

  execute "create the #{project} service" do
    environment (os_adminrc())

    name = service['name']
    desc = service['description']

    command <<-EOH
      openstack service create \
        --name "#{name}" --description "#{desc}" #{type}
    EOH

    not_if "openstack service list | grep #{type}"
  end

  %w(admin internal public).each{|uri|

    url = generate_service_catalog_uri(service,uri)

    execute "create the #{project} #{type} #{uri} endpoint" do
      environment (os_adminrc())

      command <<-EOH
        openstack endpoint create \
          --region #{region} #{type} #{uri} '#{url}'
      EOH

      not_if "openstack endpoint list \
        | grep #{type} | grep #{uri}
      "
    end

  }
end
#
# create compute service and endpoints ends


# create placement user starts
#
execute 'create openstack placement user' do
  environment (os_adminrc())

  command <<-EOH
    openstack user create \
      --domain #{service_domain} \
      --password #{placement_os_password} \
      #{placement_os_user}
  EOH

  not_if "openstack user show \
    --domain default #{placement_os_user}
  "
end

execute 'add admin role to placement user' do
  environment (os_adminrc())

  command <<-EOH
    openstack role add \
      --project #{service_project} \
      --user #{placement_os_user} \
      #{admin_role}
  EOH

  not_if "
    openstack role assignment list \
      --names \
      --role #{admin_role} \
      --project #{service_project} \
      --user #{placement_os_user} | grep #{placement_os_user}
  "
end
#
# create placement user ends

%w{nova-scheduler nova-cert nova-consoleauth nova-conductor}.each do |pkg|
    package pkg do
        action :install
    end
    service pkg do
        action [:enable, :start]
        subscribes :restart, "template[/etc/nova/nova.conf]", :delayed
        subscribes :restart, "template[/etc/nova/api-paste.ini]", :delayed
    end

  }
end
#
# create placement service and endpoints ends


# nova package installation and service definition starts
#
package 'nova-api'
package 'nova-conductor'
package 'nova-consoleauth'
package 'nova-novncproxy'
package 'nova-scheduler'
package 'nova-placement-api'

service 'nova-api'
service 'nova-consoleauth'
service 'nova-scheduler'
service 'nova-conductor'
service 'nova-novncproxy'
service 'placement-api' do
  service_name 'apache2'
end
#
# nova package installation and service definition ends


# ssl certs starts
#
template "/etc/nova/ssl-bcpc.pem" do
  source "ssl-bcpc.pem.erb"
  owner "nova"
  group "nova"
  mode 00644
end

template "/etc/nova/ssl-bcpc.key" do
  source "ssl-bcpc.key.erb"
  owner "nova"
  group "nova"
  mode 00600
end
#
# ssl certs ends


# create/manage nova databases starts
#
file '/tmp/nova-create-db.sql' do
  action :nothing
end
#
# create/manage nova databases ends


# configure nova starts
#
template '/etc/nova/nova.conf' do
  source 'nova/nova.conf.erb'

template '/tmp/nova-create-db.sql' do
  source 'nova/nova-create-db.sql.erb'

  variables(
    'nova_db' => nova_db,
    'nova_api_db' => nova_api_db,
    'nova_db_user' => nova_db_user,
    'nova_db_password' => nova_db_password
  )

  notifies :run, 'execute[create nova databases]', :immediately
  not_if "mysql -u #{mysql_root_user} \
                -e 'show databases' | grep #{nova_db}",
          :environment => {'MYSQL_PWD' => mysql_root_password}
end

execute 'create nova databases' do
  action :nothing
  environment ({'MYSQL_PWD' => mysql_root_password})

  command "mysql -u #{mysql_root_user} < /tmp/nova-create-db.sql"

  notifies :delete, 'file[/tmp/nova-create-db.sql]', :immediately
  notifies :create, 'template[/etc/nova/nova.conf]', :immediately
  notifies :run, 'execute[nova-manage api_db sync]', :immediately
  notifies :run, 'execute[register the cell0 database]', :immediately
  notifies :run, 'execute[create the cell1 cell]', :immediately
  notifies :run, 'execute[nova-manage db sync]', :immediately
  notifies :run, 'execute[update cell1]', :immediately
  notifies :restart, 'service[nova-api]', :immediately
  notifies :restart, 'service[nova-consoleauth]', :immediately
  notifies :restart, 'service[nova-scheduler]', :immediately
  notifies :restart, 'service[nova-conductor]', :immediately
  notifies :restart, 'service[nova-novncproxy]', :immediately
end

execute 'nova-manage api_db sync' do
  action :nothing
  command "su -s /bin/sh -c 'nova-manage api_db sync' nova"
end

execute 'register the cell0 database' do
  action :nothing
  command "su -s /bin/sh -c 'nova-manage cell_v2 map_cell0' nova"
  not_if "nova-manage cell_v2 list_cells | grep cell0"
end

execute 'create the cell1 cell' do
  action :nothing
  command "su -s /bin/sh -c 'nova-manage cell_v2 create_cell --name=cell1' nova"
  not_if "nova-manage cell_v2 list_cells | grep cell1"
end

execute 'nova-manage db sync' do
  action :nothing
  command "su -s /bin/sh -c 'nova-manage db sync' nova"
end
#
# create/manage nova databases ends


# configure nova starts
#
template '/etc/nova/nova.conf' do
  source 'nova/nova.conf.erb'

  variables(
    'servers' => get_head_nodes()
  )

  notifies :run, 'execute[update cell1]', :immediately
  notifies :restart, 'service[nova-api]', :immediately
  notifies :restart, 'service[nova-consoleauth]', :immediately
  notifies :restart, 'service[nova-scheduler]', :immediately
  notifies :restart, 'service[nova-conductor]', :immediately
  notifies :restart, 'service[nova-novncproxy]', :immediately
end

execute 'update cell1' do
  action :nothing
  command <<-EOH
    nova-manage cell_v2 update_cell --cell_uuid \
      $(nova-manage cell_v2 list_cells | grep cell1 | awk '{print $4}')
  EOH

  only_if "nova-manage cell_v2 list_cells | grep cell1"
end
#
# configure nova ends


# configure placement-api starts
#
template "/etc/apache2/sites-available/nova-placement-api.conf" do
  source   "nova/nova-placement-api.conf.erb"
  mode     "0644"

  variables(
    'processes' => node['bcpc']['placement']['wsgi']['processes'],
    'threads'   => node['bcpc']['placement']['wsgi']['threads']
  )

  notifies :reload, "service[placement-api]", :immediately
end
#
# configure placement-api ends


execute 'wait for nova to come online' do
  environment (os_adminrc())
  retries 15
  command 'openstack compute service list'
end
