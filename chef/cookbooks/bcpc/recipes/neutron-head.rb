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
include_recipe "bcpc::calico-head"

region = node['bcpc']['cloud']['region']
config = data_bag_item(region,'config')

mysqladmin = mysqladmin()

# hash used for database creation and access
#
database = {
  'host' => node['bcpc']['mysql']['host'],
  'dbname' => node['bcpc']['neutron']['db']['dbname'],
  'username' => config['neutron']['creds']['db']['username'],
  'password' => config['neutron']['creds']['db']['password']
}

# hash used for openstack access
#
openstack = {
  'role' => node['bcpc']['keystone']['roles']['admin'],
  'project' => node['bcpc']['keystone']['service_project']['name'],
  'domain' => node['bcpc']['keystone']['service_project']['domain'],
  'username' => config['neutron']['creds']['os']['username'],
  'password' => config['neutron']['creds']['os']['password']
}

# create neutron user starts
#
execute 'create the neutron user' do
  environment (os_adminrc())

  command <<-EOH
    openstack user create #{openstack['username']} \
      --domain #{openstack['domain']} \
      --password #{openstack['password']}
  EOH

  not_if <<-EOH
    openstack user show #{openstack['username']} --domain #{openstack['domain']}
  EOH
end

execute 'add admin role to neutron user' do
  environment (os_adminrc())

  command <<-EOH
    openstack role add #{openstack['role']} \
       --user #{openstack['username']} --project #{openstack['project']}
  EOH

  not_if <<-EOH
    openstack role assignment list --names \
      --role #{openstack['role']} \
      --project #{openstack['project']} \
      --user #{openstack['username']} | grep #{openstack['username']}
  EOH
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
package 'neutron-server'
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
    :db => database
  )
  notifies :run, 'execute[create neutron database]', :immediately
  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", :environment => {'MYSQL_PWD' => mysqladmin['password']}
end

execute 'create neutron database' do
  action :nothing
  environment ({'MYSQL_PWD' => mysqladmin['password']})

  command "mysql -u #{mysqladmin['username']} < /tmp/neutron-db.sql"

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
    :db => database,
    :os => openstack,
    :config => config,
    :nodes => get_headnodes(all:true)
  )
  notifies :restart, 'service[neutron-server]', :immediately
end

execute 'wait for neutron to come online' do
  environment (os_adminrc())
  retries 15
  command 'openstack network list'
end

node['bcpc']['neutron']['network'].each{ |network,config|

  subnets = config['subnets']

  execute "create #{network} network" do
    environment (os_adminrc())

    command <<-EOH
      openstack network create #{network} \
        --share --provider-network-type local
    EOH

    not_if "openstack network show #{network}"
  end

  subnets.each{ |subnet|

    subnet_name = subnet['name']
    cidr = subnet['cidr']

    execute "create #{network} network #{subnet_name} subnet" do
      environment (os_adminrc())

      command <<-EOH
        openstack subnet create #{subnet_name} \
          --network #{network} --subnet-range #{cidr}
      EOH

      not_if <<-EOH
        openstack subnet list --network #{network} | grep -w #{subnet_name}
      EOH
    end
  }

}
#
# configure neutron ends


# configure default security group starts
#
bash 'update admin project default security group to allow ping' do
  environment (os_adminrc())

  code <<-EOH
    project=#{node['bcpc']['openstack']['admin']['project']}
    sec_groups=$(openstack security group list -f value --project ${project})
    default_group_id=$(echo ${sec_groups} | grep default | awk '{print $1}')
    openstack security group rule create --protocol icmp $default_group_id
  EOH

  not_if "
    project=#{node['bcpc']['openstack']['admin']['project']}
    sec_groups=$(openstack security group list -f value --project ${project})
    default_group_id=$(echo ${sec_groups} | grep default | awk '{print $1}')
    openstack security group rule list $default_group_id | grep icmp
  ", :environment => os_adminrc()
end

bash 'update admin project default security group to allow ssh' do
  environment (os_adminrc())

  code <<-EOH
    project=#{node['bcpc']['openstack']['admin']['project']}
    sec_groups=$(openstack security group list -f value --project ${project})
    default_group_id=$(echo ${sec_groups} | grep default | awk '{print $1}')
    openstack security group rule create --proto tcp --dst-port 22 $default_group_id
  EOH

  not_if "
    project=#{node['bcpc']['openstack']['admin']['project']}
    sec_groups=$(openstack security group list -f value --project ${project})
    default_group_id=$(echo ${sec_groups} | grep default | awk '{print $1}')
    openstack security group rule list $default_group_id --proto tcp | grep '22:22'
  ", :environment => os_adminrc()
end
#
# configure default security group ends
