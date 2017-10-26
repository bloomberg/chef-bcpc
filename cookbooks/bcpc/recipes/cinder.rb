#
# Cookbook Name:: bcpc
# Recipe:: cinder
#
# Copyright 2013, Bloomberg Finance L.P.
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

make_config('libvirt-secret-uuid', %x[uuidgen -r].strip)

cinder_db = node['bcpc']['dbname']['cinder']
cinder_db_user = make_config('cinder-db-user', "cinder")
cinder_db_password = make_config('cinder-db-password', secure_password())

cinder_os_user = make_config('cinder-os-user', "cinder")
cinder_os_password = make_config('cinder-os-password', secure_password())

region          = node['bcpc']['region_name']
admin_role      = node['bcpc']['keystone']['admin_role']
service_project = node['bcpc']['keystone']['service_project']['name']
service_domain  = node['bcpc']['keystone']['service_project']['domain']


# create client.cinder ceph user and keyring starts
#
execute 'get or create client.cinder user/keyring' do

  enabled_pools = node['bcpc']['ceph']['enabled_pools']

  vol_perms = enabled_pools.collect{|p|
    "allow rwx pool=volumes-#{p}"
  }.join(',')

  command <<-EOH
    ceph auth get-or-create client.cinder \
      mon 'allow r' \
      osd 'allow class-read object_prefix rbd_children, \
           #{vol_perms}, \
           allow rwx pool=vms, \
           allow rx pool=images' \
      -o /etc/ceph/ceph.client.cinder.keyring
  EOH
  creates '/etc/ceph/ceph.client.cinder.keyring'
end
#
# create client.cinder ceph user and keyring ends


# create ceph rbd volume pools starts
#
node['bcpc']['ceph']['enabled_pools'].each do |type|

  execute "create #{type} rados pool" do

    ceph          = node['bcpc']['ceph']

    pool_name     = ceph['volumes']['name'] + '-' + type
    pgs_per_node  = ceph['pgs_per_node']
    vol_replicas  = ceph['volumes']['replicas']
    vol_portions  = ceph['volumes']['portion']
    pools_len     = ceph['enabled_pools'].length
    ceph_osd_len  = get_ceph_osd_nodes.length
    crush_rule    = node['bcpc']['ceph'][type]['rule']

    optimal       = ceph_osd_len * pgs_per_node
    optimal       = optimal / vol_replicas
    optimal       = optimal * vol_portions / 100 / pools_len
    optimal       = power_of_2(optimal)

    command <<-EOH
      ceph osd pool create #{pool_name} #{optimal} #{optimal} #{crush_rule}
    EOH

    not_if "rados lspools | grep #{pool_name}"
  end

  execute "set #{type} rados pool replicas" do
    name = "#{node['bcpc']['ceph']['volumes']['name']}-#{type}"

    ceph_osd_len  = search_nodes("recipe", "ceph-osd").length
    vol_replicas  = node['bcpc']['ceph']['volumes']['replicas']
    replicas      = [ceph_osd_len, vol_replicas].min

    if replicas < 1; then
        replicas = 1
    end

    command "ceph osd pool set #{name} size #{replicas}"

    not_if "ceph osd pool get #{name} size | grep #{replicas}"
  end

  auto_adjust = ['pg_num']

  if node['bcpc']['ceph']['pgp_auto_adjust']
    auto_adjust.push('pgp_num')
  end

  auto_adjust.each do |pg|
    execute "auto adjust #{type} rados pool" do
      name = "#{node['bcpc']['ceph']['volumes']['name']}-#{type}"

      osd_node_len      = get_ceph_osd_nodes.length
      pgs_per_node      = node['bcpc']['ceph']['pgs_per_node']
      vol_replicas      = node['bcpc']['ceph']['volumes']['replicas']
      vol_portion       = node['bcpc']['ceph']['volumes']['portion']
      enabled_pool_len  = node['bcpc']['ceph']['enabled_pools'].length

      optimal = osd_node_len * pgs_per_node
      optimal = optimal / vol_replicas
      optimal = optimal * vol_portion
      optimal = optimal / 100
      optimal = optimal / enabled_pool_len
      optimal = power_of_2(optimal)

      command "ceph osd pool set #{name} #{pg} #{optimal}"

      only_if { %x[ceph osd pool get #{name} #{pg} | awk '{print $2}'].to_i < optimal }
    end
  end

end
#
# create ceph rbd volume pools ends


# create cinder openstack user starts
#
execute 'create cinder openstack user' do
  environment (os_adminrc())

  command <<-EOH
    openstack user create \
      --domain #{service_domain} \
      --password #{cinder_os_password} \
      #{cinder_os_user}
  EOH

  not_if "openstack user show \
    --domain #{service_domain} #{cinder_os_user}
  "
end

execute 'add openstack admin role to cinder user' do
  environment (os_adminrc())

  command <<-EOH
    openstack role add \
      --project #{service_project} \
      --user #{cinder_os_user} \
      #{admin_role}
  EOH

  not_if "
    openstack role assignment list \
      --names \
      --role #{admin_role} \
      --project #{service_project} \
      --user #{cinder_os_user} | grep #{cinder_os_user}
  "
end
#
# create cinder openstack user ends


# create cinder volume services and endpoints starts
#
begin

  type = 'volumev3'
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
# create cinder volume services and endpoints ends


# cinder package installation and service definition starts
#
package 'cinder-api'
package 'cinder-scheduler'
package 'cinder-volume'

service 'cinder-api' do
  service_name 'apache2'
end
service 'cinder-volume'
service 'cinder-scheduler'
#
# cinder package installation and service definition starts


# update the file permissions on ceph.client.cinder.keyring to allow the
# cinder user to use ceph
#
file '/etc/ceph/ceph.client.cinder.keyring' do
  mode '0640'
  owner 'root'
  group 'cinder'
end


# create/manage cinder database starts
#
file '/tmp/cinder-db.sql' do
  action :nothing
end

template '/tmp/cinder-db.sql' do
  source 'cinder/cinder-db.sql.erb'

  variables(
    'cinder_db' => cinder_db,
    'cinder_db_user' => cinder_db_user,
    'cinder_db_password' => cinder_db_password
  )

  notifies :run, 'execute[create cinder database]', :immediately

  not_if "mysql -u #{mysql_root_user} \
                -e 'show databases' | grep #{cinder_db}",
         :environment => {'MYSQL_PWD' => mysql_root_password}
end

execute 'create cinder database' do
  action :nothing
  environment ({'MYSQL_PWD' => mysql_root_password})

  command "mysql -u #{mysql_root_user} < /tmp/cinder-db.sql"

  notifies :delete, 'file[/tmp/cinder-db.sql]', :immediately
  notifies :create, 'template[/etc/apache2/conf-available/cinder-wsgi.conf]', :immediately
  notifies :create, 'template[/etc/cinder/cinder.conf]', :immediately
  notifies :run, 'execute[cinder-manage db sync]', :immediately
end

execute 'cinder-manage db sync' do
  action :nothing
  command "su -s /bin/sh -c 'cinder-manage db sync' cinder"
end
#
# create/manage cinder database ends



# configure cinder service starts
#
template "/etc/apache2/conf-available/cinder-wsgi.conf" do
  source "cinder/cinder-wsgi.conf.erb"
  variables(
    'processes' => node['bcpc']['cinder']['wsgi']['processes'],
    'threads'   => node['bcpc']['cinder']['wsgi']['threads']
  )
  notifies :reload, "service[cinder-api]", :immediately
end

template "/etc/cinder/cinder.conf" do
  source "cinder/cinder.conf.erb"
  owner "cinder"
  group "cinder"
  mode "0600"
  variables(
    'servers' => get_head_nodes()
  )
  notifies :restart, "service[cinder-api]", :immediately
  notifies :restart, "service[cinder-volume]", :immediately
  notifies :restart, "service[cinder-scheduler]", :immediately
end

template "/etc/cinder/policy.json" do
  source "cinder-policy.json.erb"
  owner "cinder"
  group "cinder"
  mode 00600
  variables(
    'policy' => JSON.pretty_generate(node['bcpc']['cinder']['policy'])
  )
end
#
# configure cinder service ends


execute 'wait for cinder to come online' do
  environment (os_adminrc())
  retries 30
  command 'openstack volume service list'
end


# create cinder volume types starts
#
node['bcpc']['ceph']['enabled_pools'].each do |type|

  execute "create #{type} cinder backend type" do
    environment (os_adminrc())
    command <<-EOH
      openstack volume type create #{type.upcase}
      openstack volume type set #{type.upcase} \
        --property volume_backend_name=#{type.upcase}
    EOH
    not_if "openstack volume type show #{type.upcase}"
  end

end
#
# create cinder volume types ends



=begin
include_recipe "bcpc::mysql-head"
include_recipe "bcpc::ceph-head"
include_recipe "bcpc::openstack"

ruby_block "initialize-cinder-config" do
  block do
    make_config('mysql-cinder-user', "cinder")
    make_config('mysql-cinder-password', secure_password)
    make_config('keystone-cinder-password', secure_password)
    make_config('libvirt-secret-uuid', %x[uuidgen -r].strip)
  end
end

# for Mitaka, move pool creation to before Cinder installation
# (Cinder now gets very unhappy if the pools are not present on startup)
node['bcpc']['ceph']['enabled_pools'].each do |type|

  bash "create-cinder-rados-pool-#{type}" do

    ceph          = node['bcpc']['ceph']

    pool_name     = ceph['volumes']['name'] + '-' + type
    pgs_per_node  = ceph['pgs_per_node']
    vol_replicas  = ceph['volumes']['replicas']
    vol_portions  = ceph['volumes']['portion']
    pools_len     = ceph['enabled_pools'].length
    ceph_osd_len  = get_ceph_osd_nodes.length
    crush_rule    = node['bcpc']['ceph'][type]['ruleset']

    optimal       = ceph_osd_len * pgs_per_node
    optimal       = optimal / vol_replicas
    optimal       = optimal * vol_portions / 100 / pools_len
    optimal       = power_of_2(optimal)

    code <<-EOH
      ceph osd pool create #{pool_name} #{optimal} #{optimal} #{crush_rule}
    EOH

    not_if "rados lspools | grep #{pool_name}"
    notifies :run, "bash[wait-for-pgs-creating]", :immediately
  end

  bash "set-cinder-rados-pool-replicas-#{type}" do
    name = "#{node['bcpc']['ceph']['volumes']['name']}-#{type}"

    ceph_osd_len  = search_nodes("recipe", "ceph-osd").length
    vol_replicas  = node['bcpc']['ceph']['volumes']['replicas']
    replicas      = [ceph_osd_len, vol_replicas].min

    if replicas < 1; then
        replicas = 1
    end

    code "ceph osd pool set #{name} size #{replicas}"
    not_if "ceph osd pool get #{name} size | grep #{replicas}"
  end

  auto_adjust = ['pg_num']

  if node['bcpc']['ceph']['pgp_auto_adjust']
    auto_adjust.push('pgp_num')
  end

  auto_adjust.each do |pg|
    bash "set-cinder-rados-pool-#{pg}-#{type}" do
      name = "#{node['bcpc']['ceph']['volumes']['name']}-#{type}"

      osd_node_len      = get_ceph_osd_nodes.length
      pgs_per_node      = node['bcpc']['ceph']['pgs_per_node']
      vol_replicas      = node['bcpc']['ceph']['volumes']['replicas']
      vol_portion       = node['bcpc']['ceph']['volumes']['portion']
      enabled_pool_len  = node['bcpc']['ceph']['enabled_pools'].length

      optimal = osd_node_len * pgs_per_node
      optimal = optimal / vol_replicas
      optimal = optimal * vol_portion
      optimal = optimal / 100
      optimal = optimal / enabled_pool_len

      code "ceph osd pool set #{name} #{pg} #{optimal}"

      only_if { %x[ceph osd pool get #{name} #{pg} | awk '{print $2}'].to_i < optimal }
      notifies :run, "bash[wait-for-pgs-creating]", :immediately
    end
  end

end


%w{cinder-api cinder-volume cinder-scheduler cinder-common}.each do |pkg|
  package pkg do
    action :install
  end
end

%w{cinder-volume cinder-scheduler}.each do |pkg|
  service pkg do
    action [:enable, :start]
  end
end

# Patch cinder to prevent throwing 403 even policy is successful
bcpc_patch 'cinder-policy-patch' do
  patch_file           'cinder-policy.patch'
  patch_root_dir       '/usr/lib/python2.7/dist-packages'
  shasums_before_apply 'cinder-policy-BEFORE.SHASUMS'
  shasums_after_apply  'cinder-policy-AFTER.SHASUMS'
  only_if "dpkg --compare-versions $(dpkg-query --showformat='${Version}' --show cinder-api) ge 2:0 && dpkg --compare-versions $(dpkg-query --showformat='${Version}' --show cinder-api) le 2:9"
end

service "cinder-api" do
    restart_command "service cinder-api restart; sleep 5"
    action :restart
end

template "/etc/apache2/conf-available/cinder-wsgi.conf" do
  source "cinder/cinder-wsgi.conf.erb"
  variables(
    :processes => node['bcpc']['cinder']['wsgi']['processes'],
    :threads   => node['bcpc']['cinder']['wsgi']['threads']
  )
  notifies :restart, "service[cinder-api]", :immediately
end

template "/etc/cinder/cinder.conf" do
    source "cinder/cinder.conf.erb"
    owner "cinder"
    group "cinder"
    mode "0600"
    variables(
      lazy {
        {
          :servers => get_head_nodes,
          :partials => {
            "keystone/keystone_authtoken.snippet.erb" => {
              "variables" => {
                username: node['bcpc']['cinder']['user'],
                password: get_config('keystone-cinder-password')
              }
            }
          }
        }
      }
    )
    notifies :restart, "service[cinder-api]", :immediately
    notifies :restart, "service[cinder-volume]", :immediately
    notifies :restart, "service[cinder-scheduler]", :immediately
end

template "/etc/cinder/policy.json" do
    source "cinder-policy.json.erb"
    owner "cinder"
    group "cinder"
    mode 00600
    variables(:policy => JSON.pretty_generate(node['bcpc']['cinder']['policy']))
end

ruby_block "cinder-database-creation" do
    block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -uroot -e "CREATE DATABASE #{node['bcpc']['dbname']['cinder']};"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['cinder']}.* TO '#{get_config('mysql-cinder-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-cinder-password')}';"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['cinder']}.* TO '#{get_config('mysql-cinder-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-cinder-password')}';"
            mysql -uroot -e "FLUSH PRIVILEGES;"
        ]
        self.notifies :run, "bash[cinder-database-sync]", :immediately
        self.resolve_notification_references
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['cinder']}\"'|grep \"#{node['bcpc']['dbname']['cinder']}\" >/dev/null" }
end

ruby_block 'update-cinder-db-schema-for-upgrade' do
  block do
    self.notifies :run, "bash[cinder-database-sync]", :immediately
    self.resolve_notification_references
  end
  only_if { ::File.exist?('/usr/local/etc/openstack_upgrade') }
end

bash "cinder-database-sync" do
    action :nothing
    user "root"
    code "cinder-manage db sync"
    notifies :restart, "service[cinder-api]", :immediately
    notifies :restart, "service[cinder-volume]", :immediately
    notifies :restart, "service[cinder-scheduler]", :immediately
end

# Configure the glance keystone bits
# https://docs.openstack.org/mitaka/install-guide-ubuntu/glance-install.html
domain = node['bcpc']['keystone']['service_project']['domain']
cinder_username = node['bcpc']['cinder']['user']
cinder_project_name = node['bcpc']['keystone']['service_project']['name']
admin_role_name = node['bcpc']['keystone']['admin_role']

ruby_block 'keystone-create-cinder-user' do
  block do
    cmd = "openstack user create --domain #{domain} " +
          "--password #{get_config('keystone-cinder-password')} #{cinder_username}"
    execute_in_keystone_admin_context(cmd)
  end
  not_if {
    cmd = "openstack user show --domain #{domain} #{cinder_username}"
    execute_in_keystone_admin_context(cmd)
  }
end

ruby_block 'keystone-assign-cinder-admin-role' do
  opts = [
    "--user-domain #{domain}",
    "--project-domain #{domain}",
    "--user #{cinder_username}",
    "--project #{cinder_project_name}"
  ]
  block do
    cmd = "openstack role add " + opts.join(' ') + ' ' + admin_role_name
    execute_in_keystone_admin_context(cmd)
  end
  not_if {
    cmd = 'openstack role assignment list '
    g_opts = opts + [
      '-f value -c Role',
      "--role #{admin_role_name}",
      "| grep ^#{get_keystone_role_id(admin_role_name)}$"
    ]
    cmd += g_opts.join(' ')
    execute_in_keystone_admin_context(cmd)
  }
end

# Write out cinder openrc
template '/root/openrc-cinder' do
  source 'keystone/openrc.erb'
  mode '0600'
  variables(
    lazy {
      {
        username: cinder_username,
        password: get_config('keystone-cinder-password'),
        project_name: cinder_project_name,
        domain: domain
      }
    }
  )
end

# this is a synchronization resource that polls Cinder until it stops returning 503s
bash 'wait-for-cinder-to-become-operational' do
  code '. /root/openrc-cinder; until cinder list >/dev/null 2>&1; do sleep 1; done'
  timeout 120
end

node['bcpc']['ceph']['enabled_pools'].each do |type|
    bash "cinder-make-type-#{type}" do
        user "root"
        code <<-EOH
            . /root/openrc-cinder
            cinder type-create #{type.upcase}
            cinder type-key #{type.upcase} set volume_backend_name=#{type.upcase}
        EOH
        not_if ". /root/openrc-cinder; cinder type-list | grep #{type.upcase}"
    end
end

node['bcpc']['cinder']['quota'].each do |k, v|
  bash "cinder-set-default-#{k}-quota" do
    user "root"
    code <<-EOH
      . /root/openrc-cinder
      cinder quota-class-update --#{k} #{v} default
    EOH
  end
end

service "tgt" do
    action [:stop, :disable]
end

template "/etc/logrotate.d/cinder-common" do
    source "cinder/cinder-common.logrotate.conf.erb"
    owner "root"
    group "root"
    mode 00644
end
