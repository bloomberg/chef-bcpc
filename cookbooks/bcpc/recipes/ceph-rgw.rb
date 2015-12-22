#
# Cookbook Name:: bcpc
# Recipe:: ceph-rgw
#
# Copyright 2015, Bloomberg Finance L.P.
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

#RGW Stuff
#Note, currently rgw cannot use Keystone to auth S3 requests, only swift, so for the time being we'll have
#to manually provision accounts for RGW in the radosgw-admin tool

include_recipe "bcpc::apache2"
include_recipe "bcpc::ceph-work"

package "radosgw" do
    action :install
    version node['bcpc']['ceph']['version']
end

package "python-boto"

directory "/var/lib/ceph/radosgw/ceph-radosgw.gateway" do
    owner "root"
    group "root"
    mode 0755
    action :create
    recursive true
end

file "/var/lib/ceph/radosgw/ceph-radosgw.gateway/done" do
    owner "root"
    group "root"
    mode "0644"
    action :touch
end

bash "write-client-radosgw-key" do
    code <<-EOH
        RGW_KEY=`ceph --name client.admin --keyring /etc/ceph/ceph.client.admin.keyring auth get-or-create-key client.radosgw.gateway osd 'allow rwx' mon 'allow rw'`
        ceph-authtool "/var/lib/ceph/radosgw/ceph-radosgw.gateway/keyring" \
            --create-keyring \
            --name=client.radosgw.gateway \
            --add-key="$RGW_KEY"
        chmod 644 /var/lib/ceph/radosgw/ceph-radosgw.gateway/keyring
    EOH
    not_if "test -f /var/lib/ceph/radosgw/ceph-radosgw.gateway/keyring"
    notifies :restart, "service[radosgw-all]", :delayed
end

rgw_optimal_pg = power_of_2(get_ceph_osd_nodes.length*node['bcpc']['ceph']['pgs_per_node']/node['bcpc']['ceph']['rgw']['replicas']*node['bcpc']['ceph']['rgw']['portion']/100)

rgw_rule = (node['bcpc']['ceph']['rgw']['type'] == "ssd") ? node['bcpc']['ceph']['ssd']['ruleset'] : node['bcpc']['ceph']['hdd']['ruleset']

%w{.rgw .rgw.control .rgw.gc .rgw.root .users.uid .users.email .users .usage .log .intent-log .rgw.buckets .rgw.buckets.index .rgw.buckets.extra}.each do |pool|
    bash "create-rados-pool-#{pool}" do
        code <<-EOH
            ceph osd pool create #{pool} #{rgw_optimal_pg}
            ceph osd pool set #{pool} crush_ruleset #{rgw_rule}
        EOH
        not_if "rados lspools | grep ^#{pool}$"
        notifies :run, "bash[wait-for-pgs-creating]", :immediately
    end
    bash "set-#{pool}-rados-pool-replicas" do
        user "root"
        replicas = [search_nodes("recipe", "ceph-osd").length, node['bcpc']['ceph']['rgw']['replicas']].min
        if replicas < 1; then
            replicas = 1
        end
        code "ceph osd pool set #{pool} size #{replicas}"
        not_if "ceph osd pool get #{pool} size | grep #{replicas}"
    end
end

# check to see if we should up the number of pg's now for the core buckets pool
(node['bcpc']['ceph']['pgp_auto_adjust'] ? %w{pg_num pgp_num} : %w{pg_num}).each do |pg|
    bash "update-rgw-buckets-#{pg}" do
        user "root"
        code "ceph osd pool set .rgw.buckets #{pg} #{rgw_optimal_pg}"
        only_if { %x[ceph osd pool get .rgw.buckets #{pg} | awk '{print $2}'].to_i < rgw_optimal_pg }
        notifies :run, "bash[wait-for-pgs-creating]", :immediately
    end
end

# Leaving apache portion in so that we can switch back if needed by removing 'rgw frontends...' statement
# in ceph.conf and then restarting radosgw.
file "/var/www/s3gw.fcgi" do
    owner "root"
    group "root"
    mode 0755
    content "#!/bin/sh\n exec /usr/bin/radosgw -c /etc/ceph/ceph.conf -n client.radosgw.gateway"
    notifies :restart, "service[radosgw-all]", :immediately
end

template "/etc/apache2/sites-available/radosgw.conf" do
    source "apache-radosgw.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end

# Handle radosgw apache site
case node['bcpc']['ceph']['frontend']
when "civitweb"
    bash "apache-disable-radosgw" do
        user "root"
        code "a2dissite radosgw"
        only_if "test -r /etc/apache2/sites-enabled/radosgw.conf"
        notifies :restart, "service[apache2]", :immediately
    end
else
    bash "apache-enable-radosgw" do
        user "root"
        code "a2ensite radosgw"
        not_if "test -r /etc/apache2/sites-enabled/radosgw.conf"
        notifies :restart, "service[apache2]", :immediately
    end
end
# End apache configs

service "radosgw-all" do
  provider Chef::Provider::Service::Upstart
  action [ :enable, :start ]
end 

ruby_block "initialize-radosgw-admin-user" do
    block do
        make_config('radosgw-admin-user', "radosgw")
        make_config('radosgw-admin-access-key', secure_password_alphanum_upper(20))
        make_config('radosgw-admin-secret-key', secure_password(40))
        rgw_admin = JSON.parse(%x[radosgw-admin user create --display-name="Admin" --uid="radosgw" --access_key=#{get_config('radosgw-admin-access-key')} --secret=#{get_config('radosgw-admin-secret-key')}])
    end
    not_if "radosgw-admin user info --uid='radosgw'"
end

ruby_block "initialize-radosgw-test-user" do
    block do
        make_config('radosgw-test-user', "tester")
        make_config('radosgw-test-access-key', secure_password_alphanum_upper(20))
        make_config('radosgw-test-secret-key', secure_password(40))
        rgw_admin = JSON.parse(%x[radosgw-admin user create --display-name="Tester" --uid="tester" --max-buckets=3 --access_key=#{get_config('radosgw-test-access-key')} --secret=#{get_config('radosgw-test-secret-key')} --caps="usage=read; user=read; bucket=read;" ])
    end
    not_if "radosgw-admin user info --uid='tester'"
end

template "/usr/local/bin/radosgw_check.py" do
    source "radosgw_check.py.erb"
    mode 0700
    owner "root"
    group "root"
end
