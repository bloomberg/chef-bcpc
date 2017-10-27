#
# Cookbook Name:: bcpc
# Recipe:: keystone
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

include_recipe "bcpc::mysql-head"
include_recipe "bcpc::openstack"
include_recipe "bcpc::apache2"

# Override keystone from starting
cookbook_file "/etc/init/keystone.override" do
  owner "root"
  group "root"
  mode "0644"
  source "keystone/init.keystone.override"
end

begin
  make_config('mysql-keystone-user', "keystone")
  make_config('mysql-keystone-password', secure_password)
  make_config('keystone-admin-token', secure_password)
  make_config('keystone-local-admin-password', secure_password)
  make_config('keystone-admin-user',
              node["bcpc"]["ldap"]["admin_user"] || node["bcpc"]["keystone"]["admin"]["username"])
  make_config('keystone-admin-password',
              node["bcpc"]["ldap"]["admin_pass"] || get_config('keystone-local-admin-password'))
  make_config('keystone-admin-project-name',
              node['bcpc']['ldap']['admin_project_name'] || node["bcpc"]["keystone"]["admin"]["project_name"])
  make_config('keystone-admin-project-domain',
              node['bcpc']['ldap']['admin_project_domain'] || node["bcpc"]["keystone"]["admin"]["project_domain"])
  make_config('keystone-admin-user-domain',
              node['bcpc']['ldap']['admin_user_domain'] || node["bcpc"]["keystone"]["admin"]["user_domain"])
  begin
      get_config('keystone-pki-certificate')
  rescue
      temp = %x[openssl req -new -x509 -passout pass:temp_passwd -newkey rsa:2048 -out /dev/stdout -keyout /dev/stdout -days 1095 -subj "/C=#{node['bcpc']['country']}/ST=#{node['bcpc']['state']}/L=#{node['bcpc']['location']}/O=#{node['bcpc']['organization']}/OU=#{node['bcpc']['region_name']}/CN=keystone.#{node['bcpc']['cluster_domain']}/emailAddress=#{node['bcpc']['keystone']['admin_email']}"]
      make_config('keystone-pki-private-key', %x[echo "#{temp}" | openssl rsa -passin pass:temp_passwd -out /dev/stdout])
      make_config('keystone-pki-certificate', %x[echo "#{temp}" | openssl x509])
  end
end

package 'python-ldappool' do
  action :upgrade
end

package 'keystone' do
  action :upgrade
  notifies :run, 'bash[flush-memcached]', :immediately
end

# sometimes the way tokens are stored changes and causes issues,
# so flush memcached if Keystone is upgraded
bash 'flush-memcached' do
  code "echo flush_all | nc #{node['bcpc']['management']['ip']} 11211"
  action :nothing
end

# these packages need to be updated in Liberty but are not upgraded when Keystone is upgraded
%w( python-oslo.i18n python-oslo.serialization python-pyasn1 ).each do |pkg|
  package pkg do
    action :upgrade
    notifies :restart, "service[apache2]", :immediately
  end
end

# do not run or try to start standalone keystone service since it is now served by WSGI
service "keystone" do
    action [:disable, :stop]
end

# if on Liberty, generate Fernet keys and persist the keys in the data bag (if not already
# generated)
fernet_key_directory = '/etc/keystone/fernet-keys'

directory fernet_key_directory do
  owner 'keystone'
  group 'keystone'
  mode "0700"
end

# write out keys if defined in the data bag
# (there should always be at least 0 (staged) and 1 (primary) in the data bag)
ruby_block 'write-out-fernet-keys-from-data-bag' do
  block do
    (0..2).each do |idx|
      if config_defined("keystone-fernet-key-#{idx}")
        key_path = ::File.join(fernet_key_directory, idx.to_s)
        key_in_databag = get_config("keystone-fernet-key-#{idx}")
        ::File.write(key_path, key_in_databag)
      end
    end
    # remove any other keys present in the directory (not 0, 1, or 2)
    ::Dir.glob(::File.join(fernet_key_directory, '*')).reject do |path|
      path.end_with?(*(0..2).collect(&:to_s))
    end.each do |file_to_delete|
      ::File.delete(file_to_delete)
    end
  end
  # if any key needs to be rewritten, then we'll rewrite them all
  only_if do
    need_to_write_keys = []
    (0..2).each do |idx|
      key_path = ::File.join(fernet_key_directory, idx.to_s)
      if ::File.exist?(key_path)
        key_on_disk = ::File.read(key_path)
        if config_defined("keystone-fernet-key-#{idx}")
          need_to_write_keys << (key_on_disk != get_config("keystone-fernet-key-#{idx}"))
        end
      else
        # key does not exist on disk, ensure that it is written out
        need_to_write_keys << true
      end
    end
    need_to_write_keys.any?
  end
  notifies :restart, 'service[apache2]', :immediately
end

# generate Fernet keys if there are not any on disk (first time setup)
ruby_block 'first-time-fernet-key-generation' do
  block do
    Mixlib::ShellOut.new('keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone').run_command.error!
    make_config('keystone-fernet-last-rotation', Time.now)
  end
  not_if { ::File.exist?(::File.join(fernet_key_directory, '0')) }
  notifies :restart, 'service[apache2]', :immediately
end

# if the staged key's mtime is at least this many days old and the data bag
# has recorded a last rotation timestamp , execute a rotation
ruby_block 'rotate-fernet-keys' do
  block do
    fernet_keys = ::Dir.glob(::File.join(fernet_key_directory, '*')).sort

    # the current staged key (0) will become the new master
    new_master_key = ::File.read(fernet_keys.first)
    # the current master key (highest index) will become a secondary key
    old_master_key = ::File.read(fernet_keys.last)
    # execute a rotation via keystone-manage so that we get a new staging key
    Mixlib::ShellOut.new('keystone-manage fernet_rotate --keystone-user keystone --keystone-group keystone').run_command.error!
    # 0 is now the new staging key so read that file again
    new_staging_key = ::File.read(fernet_keys.first)

    # destroy the on-disk keys before we rewrite them to disk
    ::Dir.glob(::File.join(fernet_key_directory, '*')).each do |fk|
      ::File.delete(fk)
    end

    # write new master key to 2
    ::File.write(::File.join(fernet_key_directory, '2'), new_master_key)
    # write staging key to 0
    ::File.write(::File.join(fernet_key_directory, '0'), new_staging_key)
    # write old master key to 1
    ::File.write(::File.join(fernet_key_directory, '1'), old_master_key)

    # re-permission all keys to ensure they are owned by keystone and chmod 600
    Mixlib::ShellOut.new('chown keystone:keystone /etc/keystone/fernet-keys/*').run_command.error!
    Mixlib::ShellOut.new('chmod 0600 /etc/keystone/fernet-keys/*').run_command.error!

    # update keystone-fernet-last-rotation timestamp
    make_config('keystone-fernet-last-rotation', Time.now.to_i, force=true)

    # (writing these keys into the data bag will be done by the add-fernet-keys-to-data-bag resource)
  end
  only_if do
    # if key rotation is disabled then skip out
    if node['bcpc']['keystone']['rotate_fernet_tokens']
      if config_defined('keystone-fernet-last-rotation')
        Time.now.to_i - get_config('keystone-fernet-last-rotation').to_i > node['bcpc']['keystone']['fernet_token_max_age_seconds']
      else
        # always run if keystone-fernet-last-rotation is not defined
        # (upgrade from 6.0.0)
        true
      end
    else
      false
    end
  end
  notifies :restart, 'service[apache2]', :immediately
end

# key indexes in the data bag will not necessarily match the files on disk
# (staged key is always key 0, primary key is the highest-indexed one, any
# keys in between are former primary keys that can only decrypt)
ruby_block 'add-fernet-keys-to-data-bag' do
  block do
    fernet_keys = ::Dir.glob(::File.join(fernet_key_directory, '*')).sort
    fernet_keys.each_with_index do |key_path, idx|
      db_key = "keystone-fernet-key-#{idx}"
      disk_key_value = ::File.read(key_path)
      begin
        db_key_value = get_config(db_key)
        make_config(db_key, disk_key_value, force=true) unless db_key_value == disk_key_value
        # save old key to backup slot Just In Case
        make_config("#{db_key}-backup", db_key_value, force=true)
      rescue
        make_config(db_key, disk_key_value)
      end
    end
  end
  only_if do
    need_to_add_keys = []
    (0..2).each do |idx|
      key_path = ::File.join(fernet_key_directory, idx.to_s)
      if ::File.exist?(key_path)
        key_on_disk = ::File.read(key_path)
        if config_defined("keystone-fernet-key-#{idx}")
          need_to_add_keys << (key_on_disk != get_config("keystone-fernet-key-#{idx}"))
        else
          need_to_add_keys << true
        end
      end
    end
    need_to_add_keys.any?
  end
end

# standalone Keystone service has a window to start up in and create keystone.log with
# wrong permissions, so ensure it's owned by keystone:keystone
file "/var/log/keystone/keystone.log" do
  owner "keystone"
  group "keystone"
  notifies :restart, "service[apache2]", :immediately
end

domain_config_dir = node['bcpc']['keystone']['domain_config_dir']
directory domain_config_dir do
    owner "keystone"
    group "keystone"
    mode "2700"
end

template "/etc/keystone/keystone.conf" do
    source "keystone/keystone.conf.erb"
    owner "keystone"
    group "keystone"
    mode "0600"
    variables(
      lazy {
        {
          :servers => get_head_nodes
        }
      }
    )
    notifies :restart, "service[apache2]", :immediately
end

cookbook_file "/etc/keystone/keystone-paste.ini" do
    source "keystone/keystone-paste.ini"
    owner "keystone"
    group "keystone"
    mode "0600"
    notifies :restart, "service[apache2]", :immediately
end

node['bcpc']['keystone']['domains'].each do |domain, config|
  config_file = File.join domain_config_dir, "keystone.#{domain}.conf"
  template config_file do
      source "keystone/keystone.domain.conf.erb"
      owner "keystone"
      group "keystone"
      mode "0600"
      variables(
        :domain => config
      )
      # should this be here..?
      notifies :restart, "service[apache2]", :delayed
  end
end

template "/etc/keystone/default_catalog.templates" do
    source "keystone-default_catalog.templates.erb"
    owner "keystone"
    group "keystone"
    mode "0644"
    notifies :restart, "service[apache2]", :delayed
end

template "/etc/keystone/cert.pem" do
    source "keystone-cert.pem.erb"
    owner "keystone"
    group "keystone"
    mode "0644"
    notifies :restart, "service[apache2]", :delayed
end

template "/etc/keystone/key.pem" do
    source "keystone-key.pem.erb"
    owner "keystone"
    group "keystone"
    mode "0600"
    notifies :restart, "service[apache2]", :delayed
end

template "/etc/keystone/policy.json" do
    source "keystone-policy.json.erb"
    owner "keystone"
    group "keystone"
    mode "0600"
    variables(:policy => JSON.pretty_generate(node['bcpc']['keystone']['policy']))
end

template "/root/api_versionsrc" do
    source "api_versionsrc.erb"
    owner "root"
    group "root"
    mode "0600"
end

template "/root/keystonerc" do
    source "keystonerc.erb"
    owner "root"
    group "root"
    mode "0600"
end

# configure WSGI

# /var/www created by apache2 package, /var/www/cgi-bin created in bcpc::apache2
#wsgi_keystone_dir = "/var/www/cgi-bin/keystone"
#directory wsgi_keystone_dir do
#  action :create
#  owner  "root"
#  group  "root"
#  mode "0755"
#end

#%w{main admin}.each do |wsgi_link|
#  link ::File.join(wsgi_keystone_dir, wsgi_link) do
#    action :create
#    to     "/usr/share/keystone/wsgi.py"
#  end
#end

template "/etc/apache2/sites-available/wsgi-keystone.conf" do
  source   "keystone/apache-wsgi-keystone.conf.erb"
  owner    "root"
  group    "root"
  mode "0644"
  variables(
    :processes => node['bcpc']['keystone']['wsgi']['processes'],
    :threads   => node['bcpc']['keystone']['wsgi']['threads']
  )
  notifies :restart, "service[apache2]", :immediately
end

bash "a2ensite-enable-wsgi-keystone" do
  user     "root"
  code     "a2ensite wsgi-keystone"
  not_if   "test -r /etc/apache2/sites-enabled/wsgi-keystone.conf"
  notifies :restart, "service[apache2]", :immediately
end

ruby_block "keystone-database-creation" do
    block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -uroot -e "CREATE DATABASE #{node['bcpc']['dbname']['keystone']};"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['keystone']}.* TO '#{get_config('mysql-keystone-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-keystone-password')}';"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['keystone']}.* TO '#{get_config('mysql-keystone-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-keystone-password')}';"
            mysql -uroot -e "FLUSH PRIVILEGES;"
        ]
        self.notifies :run, "bash[keystone-database-sync]", :immediately
        self.resolve_notification_references
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['keystone']}\"'|grep \"#{node['bcpc']['dbname']['keystone']}\" >/dev/null" }
end

ruby_block 'update-keystone-db-schema' do
  block do
    self.notifies :run, "bash[keystone-database-sync]", :immediately
    self.resolve_notification_references
  end
  only_if {
    ::File.exist?('/usr/local/etc/openstack_upgrade') and not has_unregistered_migration?
  }
end

bash "keystone-database-sync" do
    action :nothing
    user "root"
    code "keystone-manage db_sync"
    notifies :restart, "service[apache2]", :immediately
end

ruby_block "keystone-region-creation" do
    block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -uroot -e "INSERT INTO keystone.region (id, extra) VALUES(\'#{node['bcpc']['region_name']}\', '{}');"
        ]
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT id FROM keystone.region WHERE id = \"#{node['bcpc']['region_name']}\"' | grep \"#{node['bcpc']['region_name']}\" >/dev/null" }
end

# this is a synchronization resource that polls Keystone on the VIP to verify that it's not returning 503s,
# if something above has restarted Apache and Keystone isn't ready to play yet
ruby_block "wait-for-keystone-to-become-operational" do
  delay = 1
  retries = (node['bcpc']['keystone']['wait_for_keystone_timeout']/delay).ceil
  block do
    r = execute_in_keystone_admin_context("openstack region list -fvalue")
    raise Exception.new('Still waiting for keystone') if r.strip.empty? 
  end
  retry_delay delay
  retries retries
end

# TODO(kamidzi): each service should create its *own* catalog entry
# create services and endpoint
catalog = node['bcpc']['catalog'].dup
catalog.delete('network') unless node['bcpc']['enabled']['neutron']
catalog.each do |svc, svcprops|
  # attempt to delete endpoints that no longer match the environment
  # (keys off the service type, so it is possible to orphan endpoints if you remove an
  # entry from the environment service catalog)
  ruby_block "keystone-delete-outdated-#{svc}-endpoint" do
    block do
      svc_endpoints_raw = execute_in_keystone_admin_context('openstack endpoint list -f json')
      begin
        #puts svc_endpoints_raw
        svc_endpoints = JSON.parse(svc_endpoints_raw)
        #puts svc_endpoints
        svc_ids = svc_endpoints.select { |k| k['Service Type'] == svc }.collect { |v| v['ID'] }
        #puts svc_ids
        svc_ids.each do |svc_id|
          execute_in_keystone_admin_context("openstack endpoint delete #{svc_id} 2>&1")
        end
      rescue JSON::ParserError
      end
    end
    not_if {
      svc_endpoints_raw = execute_in_keystone_admin_context('openstack endpoint list -f json')
      begin
        svc_endpoints = JSON.parse(svc_endpoints_raw)
        next if svc_endpoints.empty?
        svcs = svc_endpoints.select { |k| k['Service Type'] == svc }
        next if svcs.empty?

        adminurl_raw = svcs.select { |v| v['URL'] if v['Interface'] == 'admin' }
        adminurl = adminurl_raw.empty? ? nil : adminurl_raw[0]['URL']
        internalurl_raw = svcs.select { |v| v['URL'] if v['Interface'] == 'internal' }
        internalurl = internalurl_raw.empty? ? nil : internalurl_raw[0]['URL']
        publicurl_raw = svcs.select { |v| v['URL'] if v['Interface'] == 'public' }
        publicurl = publicurl_raw.empty? ? nil : publicurl_raw[0]['URL']

        adminurl_match = adminurl.nil? ? true : (adminurl == generate_service_catalog_uri(svcprops, 'admin'))
        internalurl_match = internalurl.nil? ? true : (internalurl == generate_service_catalog_uri(svcprops, 'internal'))
        publicurl_match = publicurl.nil? ? true : (publicurl == generate_service_catalog_uri(svcprops, 'public'))

        adminurl_match && internalurl_match && publicurl_match
      rescue JSON::ParserError
        false
      end
    }
  end

  # why no corresponding deletion for out of date services?
  # services don't get outdated in the way endpoints do (since endpoints encode version numbers and ports),
  # services just say that service X is present in the catalog, not how to access it

  ruby_block "keystone-create-#{svc}-service" do
    block do
      execute_in_keystone_admin_context("openstack service create --name '#{svcprops['name']}' --description '#{svcprops['description']}' #{svc}")
    end
    only_if {
      services_raw = execute_in_keystone_admin_context('openstack service list -f json')
      services = JSON.parse(services_raw)
      services.select { |s| s['Type'] == svc }.length.zero?
    }
  end

  # openstack command syntax changes between identity API v2 and v3, so calculate the endpoint creation command ahead of time
  identity_api_version = node['bcpc']['catalog']['identity']['uris']['public'].scan(/^[^\d]*(\d+)/)[0][0].to_i
  if identity_api_version == 3
    endpoint_create_cmd = <<-EOH
      openstack endpoint create \
          --region '#{node['bcpc']['region_name']}' #{svc} public "#{generate_service_catalog_uri(svcprops, 'public')}" ;
      openstack endpoint create \
          --region '#{node['bcpc']['region_name']}' #{svc} internal "#{generate_service_catalog_uri(svcprops, 'internal')}" ;
      openstack endpoint create \
          --region '#{node['bcpc']['region_name']}' #{svc} admin "#{generate_service_catalog_uri(svcprops, 'admin')}" ;
    EOH
  else
    endpoint_create_cmd = <<-EOH
      openstack endpoint create \
          --region '#{node['bcpc']['region_name']}' \
          --publicurl "#{generate_service_catalog_uri(svcprops, 'public')}" \
          --adminurl "#{generate_service_catalog_uri(svcprops, 'admin')}" \
          --internalurl "#{generate_service_catalog_uri(svcprops, 'internal')}" \
          #{svc}
    EOH
  end

  ruby_block "keystone-create-#{svc}-endpoint" do
    block do
      execute_in_keystone_admin_context(endpoint_create_cmd)
    end
    only_if {
      endpoints_raw = execute_in_keystone_admin_context('openstack endpoint list -f json')
      endpoints = JSON.parse(endpoints_raw)
      endpoints.select { |e| e['Service Type'] == svc }.length.zero?
    }
  end
end

# Create domains, projects, and roles
# NOTE(kamidzi): this is using legacy attribute. Maybe should change it?
default_domain = node['bcpc']['keystone']['default_domain']
member_role_name = node['bcpc']['keystone']['member_role']
service_project_name = node['bcpc']['keystone']['service_project']['name']
service_project_domain = node['bcpc']['keystone']['service_project']['domain']
admin_project_name = node['bcpc']['keystone']['admin']['project_name']
admin_role_name = node['bcpc']['keystone']['admin_role']
admin_username = node['bcpc']['keystone']['admin']['username']
# NB(kamidzi): Make sure admin project is in same domain as service project!
admin_project_domain = node['bcpc']['keystone']['admin']['project_domain']
admin_user_domain = node['bcpc']['keystone']['admin']['user_domain']

# For case... mostly migratory where ldap-backed domain already exists, sql-backed is added
admin_config = {
  sql: {
    project_name: admin_project_name,
    project_domain: admin_project_domain,
    user_domain: admin_user_domain,
    user_name: admin_username
  },
  ldap: {
      project_name: get_config('keystone-admin-project-name'),
      project_domain: get_config('keystone-admin-project-domain'),
      user_domain: get_config('keystone-admin-user-domain'),
      user_name: get_config('keystone-admin-user')
  }
}
# Create the domains
ruby_block "keystone-create-domains" do
  block do
    node['bcpc']['keystone']['domains'].each do |domain, attrs|
      name = "keystone-create-domain::#{domain}"
      desc = attrs['description'] || ''
      run_context.resource_collection << dom_create = Chef::Resource::RubyBlock.new(name, run_context)
      dom_create.block  { execute_in_keystone_admin_context("openstack domain create --description '#{desc}' #{domain}") }
      # TODO(kamidzi): if domain changes, guard will not detect
      dom_create.not_if {
        s = execute_in_keystone_admin_context("openstack domain show #{domain}"){|o,e,s| s}
        s.success?
      }

      # Configure them
      name = "keystone-configure-domain::#{domain}"
      # Use domain_config_upload for now
      run_context.resource_collection << dom_configure = Chef::Resource::RubyBlock.new(name, run_context)
      dom_configure.block  { %x{ keystone-manage domain_config_upload --domain "#{domain}"} }
      # TODO(kamidzi): need a conditional...
    end
  end
end

ruby_block "keystone-create-admin-projects" do
  block do
    admin_config.each do |backend, config|
      name = "keystone-create-admin-project::#{config[:project_name]}"
      run_context.resource_collection << project_create = Chef::Resource::RubyBlock.new(name, run_context)
      project_create.block {
        execute_in_keystone_admin_context("openstack project create --domain #{config[:project_domain]} " +
                                          "--description 'Admin Project' #{config[:project_name]}")
      }
      project_create.not_if {
        cmd = "openstack project show --domain #{config[:project_domain]} " + "#{config[:project_name]}"
        s = execute_in_keystone_admin_context(cmd){|o,e,s| s}
        s.success?
      }
    end
  end
end

ruby_block "keystone-create-admin-user" do
  block do
    execute_in_keystone_admin_context("openstack user create --domain #{admin_project_domain} --password " +
                                      "#{get_config('keystone-local-admin-password')} #{admin_username}")
  end
  not_if {
    cmd = "openstack user show --domain #{admin_project_domain} #{admin_username}"
    s = execute_in_keystone_admin_context(cmd){|o,e,s| s}
    s.success?
  }
end

# FYI: https://blueprints.launchpad.net/keystone/+spec/domain-specific-roles
ruby_block "keystone-create-admin-role" do
  block do
    execute_in_keystone_admin_context("openstack role create #{admin_role_name}")
  end
  not_if {
    s = execute_in_keystone_admin_context("openstack role show #{admin_role_name}"){|o,e,s| s}
    s.success?
  }
end

ruby_block "keystone-assign-admin-roles" do
  block do
      admin_config.each do |backend, config|
      name = "keystone-assign-admin-role::#{config[:user_domain]}::#{config[:user_name]}"
      a_cmd = "openstack role add"
      a_opts = [
        "--user-domain #{config[:user_domain]}",
        "--user #{config[:user_name]}",
        "--project-domain #{config[:project_domain]}",
        "--project #{config[:project_name]}"
      ]
      a_args = [admin_role_name]

      g_cmd = "openstack role assignment list"
      g_opts = a_opts + [
        "-fjson",
        "--role #{admin_role_name}",
      ]
      assign_cmd = ([a_cmd] + a_opts + a_args).join(' ')
      guard_cmd = ([g_cmd] + g_opts).join(' ')
      run_context.resource_collection << admin_assign = Chef::Resource::RubyBlock.new(name, run_context)
      admin_assign.block { execute_in_keystone_admin_context(assign_cmd) }
      admin_assign.only_if {
        begin
          r = JSON.parse execute_in_keystone_admin_context(guard_cmd)
          r.empty?
        rescue JSON::ParserError
          true
        end
      }
    end
  end
end

ruby_block "keystone-create-service-project" do
  block do
    execute_in_keystone_admin_context("openstack project create --domain #{service_project_domain} --description 'Service Project' #{service_project_name}")
  end
  not_if {
    cmd = "openstack project show --domain #{service_project_domain} #{service_project_name}"
    s = execute_in_keystone_admin_context(cmd){|o,e,s| s}
    s.success?
  }
end

ruby_block "keystone-create-member-role" do
  block do
    execute_in_keystone_admin_context("openstack role create #{member_role_name}")
  end
  not_if {
    s = execute_in_keystone_admin_context("openstack role show #{member_role_name}"){|o,e,s| s}
    s.success?
  }
end

# FIXME(kamidzi): this is another level of indirection because of preference to ldap
# This is legacy credentials file
template "/root/adminrc" do
    source "keystone/openrc.erb"
    owner "root"
    group "root"
    mode "0600"
    variables(
      lazy {
        {
          username: get_config('keystone-admin-user'),
          password: get_config('keystone-admin-password'),
          project_name: get_config('keystone-admin-project-name'),
          user_domain: get_config('keystone-admin-user-domain'),
          project_domain: get_config('keystone-admin-project-domain')
        }
      }
    )
end

# This is a *domain* admin in separate domain along with service accounts
template "/root/admin-openrc" do
    source "keystone/openrc.erb"
    owner "keystone"
    group "keystone"
    mode "0600"
    variables(
      lazy {
        {
          username: admin_username,
          password: get_config('keystone-local-admin-password'),
          project_name: admin_project_name,
          user_domain: admin_user_domain,
          project_domain: admin_project_domain
        }
      }
    )
end

#
# Cleanup actions
#
file "/var/lib/keystone/keystone.db" do
  action :delete
end

# Migration for user ids
# This is necessary when existing admin user is a member of an ldap-backed domain
# in single-domain deployment which then migrates to multi-domain deployment. Even
# if domain name remains the same, the user is re-issued an id. This new id needs to
# be permissioned
cookbook_file "/usr/lib/python2.7/dist-packages/keystone/common/sql/migrate_repo/versions/098_migrate_single_to_multi_domain_user_ids.py" do
  source "keystone/098_migrate_single_to_multi_domain_user_ids.py"
  owner "root"
  group "root"
  mode  "0644"
end

# User records need to be accessed to populate database with new, stable public IDs
ruby_block "keystone-list-admin-domain-users" do
  block do
    execute_in_keystone_admin_context("openstack user list --domain #{get_config('keystone-admin-user-domain')}")
  end
  notifies :run, "bash[keystone-database-sync]", :immediately
  not_if { %x[bash -c '. /root/adminrc && openstack token issue'] ; $?.success? and keystone_db_version == '98' }
end
