#
# Cookbook Name:: bcpc
# Recipe:: neutron-head
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

mysql_root_user     = get_config('mysql-root-user')
mysql_root_password = get_config('mysql-root-password')

neutron_db = node['bcpc']['dbname']['neutron']
neutron_db_user = make_config('neutron-db-user', "neutron")
neutron_db_password = make_config('neutron-db-password', secure_password())

# nova and neutron have a cross dependancy that requires neutron to know
# about nova and vice versa in their configuration files so we need this
# information available at template generation
#
neutron_os_user = make_config('neutron-os-user', "neutron")
neutron_os_password = make_config('neutron-os-password', secure_password())

package 'neutron-server' do
  action :install
end


# create neutron user starts
#
execute 'create the neutron user' do
  environment (os_adminrc())

  command <<-EOH
    openstack user create \
      --domain #{service_domain} \
      --password #{neutron_os_password} \
      #{neutron_os_user}
  EOH

  not_if "openstack user show \
    --domain #{service_domain} #{neutron_os_user}
  "
end

execute 'add admin role to neutron user' do
  environment (os_adminrc())

  command <<-EOH
    openstack role add \
      --project #{service_project} \
      --user #{neutron_os_user} \
      #{admin_role}
  EOH

  not_if "
    openstack role assignment list \
      --names \
      --role #{admin_role} \
      --project #{service_project} \
      --user #{neutron_os_user} | grep #{neutron_os_user}
  "
end
#
# create neutron user ends


# create network service and endpoints starts
#
begin
  type = 'network'
  service = node['bcpc']['catalog'][type]
  project = service['project']

  execute "create the #{project} #{type} service" do
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
# create network service and endpoints ends


# neutron package installation and service definition starts
#
%w(neutron-server).each do |pkg|
  package pkg do
    action :upgrade
  end
end

service 'neutron-server'
#
# neutron package installation and service definition ends


# create/manage neutron database starts
#
file '/tmp/neutron-db.sql' do
  action :nothing
end

template '/tmp/neutron-db.sql' do
  source 'neutron/neutron-db.sql.erb'
  variables(
    'neutron_db' => neutron_db,
    'neutron_db_user' => neutron_db_user,
    'neutron_db_password' => neutron_db_password
  )
  notifies :run, 'execute[create neutron database]', :immediately
  not_if "mysql -u #{mysql_root_user} \
                -e 'show databases' | grep #{neutron_db}",
         :environment => {'MYSQL_PWD' => mysql_root_password}
end

execute 'create neutron database' do
  action :nothing
  environment ({'MYSQL_PWD' => mysql_root_password})

  command "mysql -u #{mysql_root_user} < /tmp/neutron-db.sql"

  notifies :delete, 'file[/tmp/neutron-db.sql]', :immediately
  notifies :create, 'template[/etc/neutron/neutron.conf]', :immediately
  notifies :run, 'execute[neutron-db-manage upgrade heads]', :immediately
end

execute 'neutron-db-manage upgrade heads' do
  action :nothing
  command "su -s /bin/sh -c 'neutron-db-manage upgrade heads' neutron"
end
#
# create/manage neutron database ends


# configure neutron starts
#
template '/etc/neutron/neutron.conf' do
  source 'neutron/neutron.conf.erb'
  variables(
    'servers' => get_head_nodes()
  )
  notifies :restart, 'service[neutron-server]', :immediately
end

execute 'wait for neutron to come online' do
  environment (os_adminrc())
  retries 15
  command 'openstack network list'
end

node['bcpc']['guest_networks'].each{ |network|

  network_name = network['name']
  subnets = network['subnets']

  execute "create #{network_name} network" do
    environment (os_adminrc())

    command <<-EOH
      openstack network create \
        --share --provider-network-type local #{network_name}
    EOH

    not_if "openstack network show #{network_name}"
  end

  subnets.each{ |subnet|

    subnet_name = subnet['name']
    cidr = subnet['cidr']

    execute "create #{network_name} network #{subnet_name} subnet" do
      environment (os_adminrc())

      command <<-EOH
        openstack subnet create \
          --network #{network_name} \
          --subnet-range #{cidr} \
        #{subnet_name}
      EOH

      not_if <<-EOH
        openstack subnet list \
          --network #{network_name} | grep -w #{subnet_name}
      EOH
    end
  }

}
#
# configure neutron ends


# configure default security group starts
#
execute 'update default security group to allow ping' do
  environment (os_adminrc())

  command "openstack security group rule create \
    --proto icmp default"

  not_if "openstack security group rule list \
            --protocol icmp default | grep 'icmp'"
end

execute 'update default security group to allow ssh' do
  environment (os_adminrc())

  command <<-EOH
    openstack security group rule create \
      --proto tcp --dst-port 22 default
  EOH

  not_if "openstack security group rule list \
            --protocol tcp default \
            -c 'Port Range' | grep '22:22'"
end
#
# configure default security group ends
