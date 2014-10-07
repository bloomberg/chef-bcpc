#
# Cookbook Name:: bcpc
# Recipe:: sahara
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

include_recipe "bcpc::apache2"
require "digest"
require "json"

%w{libmysqlclient-dev python-mysqldb python-dev libxml2-dev libxslt1-dev qemu-utils}.each do |pkg|
    package pkg
end

ruby_block "initialize-sahara-config" do
    block do
        make_config('mysql-sahara-user', "sahara")
        make_config('mysql-sahara-password', secure_password)
    end
end

remote_directory "#{node["chef_client"]["cache_path"]}/pip-packages" do
    action :create_if_missing
    source "bins/pip-packages"
end

%w{pbr sahara==stable-icehouse sahara-dashboard python-saharaclient==0.7.0}.each do |pkg|
    python_pip pkg do
        action :install
        options "--no-index --find-links file://#{node["chef_client"]["cache_path"]}/pip-packages"
    end
end

# sahara requires updated version of oslo.config
python_pip "oslo.config" do
    action :upgrade
    options "--no-index --find-links file://#{node["chef_client"]["cache_path"]}/pip-packages"
end

%w{keystone_catalog_backends_templated.py.patch 
   sahara_main.py.patch
   sahara_utils_openstack_nova.py.patch
   sahara_shell.py.patch
   sahara_api_client.py.patch }.each do |file|
    cookbook_file "/tmp/#{file}" do
        source file
        owner "root"
        mode 00644
    end
end

# patch keystone endpoint template parser
# intended to patch https://github.com/openstack/keystone/blob/a96158a2dbec620c69c71c37248a5729982e050d/keystone/catalog/backends/templated.py
# fixes problem described here https://bugs.launchpad.net/sahara/+bug/1356053 -- fix made in Juno
bash "patch-for-keystone-catalog-backends-templated" do
    user "root"
    cwd "/usr/lib/python2.7/dist-packages/keystone/catalog/backends/"
    code <<-EOH
         md5=($(md5sum templated.py))
         if [ "$md5" == "5ea04d6a4c8b9d3d4bba181291a84f4e" ]; then
           patch templated.py < /tmp/keystone_catalog_backends_templated.py.patch
         else
           echo "Upstream has changed; can't patch."
           exit 2
         fi
    EOH
    notifies :restart, "service[keystone]", :immediately
    not_if {Digest::MD5.file('/usr/lib/python2.7/dist-packages/keystone/catalog/backends/templated.py').hexdigest == "94b934b005f42519da4b2cbb3cadbd20"}
end

# patch server
# intended to patch https://github.com/openstack/sahara/blob/31089652a8780d016763440e872655692556078e/sahara/main.py 
bash "patch-for-sahara-main" do
    user "root"
    cwd "/usr/local/lib/python2.7/dist-packages/sahara/"
    code <<-EOH
         md5=($(md5sum main.py))
         if [ "$md5" == "c5d94331e506cf0cca75e874f7060bf1" ]; then
           patch main.py < /tmp/sahara_main.py.patch
         else
           echo "Upstream has changed; can't patch."
           exit 2
         fi
    EOH
    notifies :restart, "service[sahara]", :delayed
    not_if {Digest::MD5.file('/usr/local/lib/python2.7/dist-packages/sahara/main.py').hexdigest == "d8f8d30a9b2c7f3e9554cb0f3877ff20"}
end

# intended to patch https://github.com/openstack/sahara/blob/31089652a8780d016763440e872655692556078e/sahara/utils/openstack/nova.py
bash "patch-for-sahara-utils-openstack-nova" do
    user "root"
    cwd "/usr/local/lib/python2.7/dist-packages/sahara/utils/openstack"
    code <<-EOH
         md5=($(md5sum nova.py))
         if [ "$md5" == "03a503e7ab3ed63986991cd56d1e7185" ]; then
           patch nova.py < /tmp/sahara_utils_openstack_nova.py.patch
         else
           echo "Upstream has changed; can't patch."
           exit 2
         fi
    EOH
    notifies :restart, "service[sahara]", :delayed
    not_if {Digest::MD5.file('/usr/local/lib/python2.7/dist-packages/sahara/utils/openstack/nova.py').hexdigest == "3d3a9dc83008c1c759b6b7fb7c913b30"}
end

# patch client
# intended to patch https://github.com/openstack/python-saharaclient/blob/adae9ecdbce35c3bc1225b819bd2378d1b0b7770/saharaclient/shell.py
bash "patch-for-sahara-shell" do
    user "root"
    cwd "/usr/local/lib/python2.7/dist-packages/saharaclient/"
    code <<-EOH
         md5=($(md5sum shell.py))
         if [ "$md5" == "ae8c2936b9e46556ed09ba994338dc02" ]; then
           patch shell.py < /tmp/sahara_shell.py.patch
         else
           echo "Upstream has changed; can't patch."
           exit 2
         fi
    EOH
    not_if {Digest::MD5.file('/usr/local/lib/python2.7/dist-packages/saharaclient/shell.py').hexdigest == "420132e48fa8a0e2bc381f2808ab84fa"}
end

# intended to patch https://github.com/openstack/python-saharaclient/blob/adae9ecdbce35c3bc1225b819bd2378d1b0b7770/saharaclient/api/client.py
bash "patch-for-sahara-api-client" do
    user "root"
    cwd "/usr/local/lib/python2.7/dist-packages/saharaclient/api/"
    code <<-EOH
         md5=($(md5sum client.py))
         if [ "$md5" == "64968052c00c56b9b3224557996d8168" ]; then
           patch client.py < /tmp/sahara_api_client.py.patch
         else
           echo "Upstream has changed; can't patch."
           exit 2
         fi
    EOH
    not_if {Digest::MD5.file('/usr/local/lib/python2.7/dist-packages/saharaclient/api/client.py').hexdigest == "711a0bbad6513342df2fc9ecaaffc9a3"}
end

%w{/etc/sahara /var/log/sahara}.each do |dir|
    directory dir do
        owner "root"
        group "root"
        mode 00600
        action :create
    end
end


template "/etc/sahara/sahara.conf" do
    source "sahara.conf.erb"
    owner "root"
    group "root"
    mode 00600
    notifies :restart, "service[sahara]", :delayed
end

file "/usr/share/openstack-dashboard/openstack_dashboard/enabled/sahara.py" do
    action :create
    content <<END
DASHBOARD = 'sahara'
ADD_INSTALLED_APPS = ['saharadashboard']
END
end

# create upstart job
file "/etc/init/sahara.conf" do
    action :create
    content <<END
description "Sahara-all server"

start on runlevel [2345]
stop on runlevel [!2345]

respawn

exec /usr/local/bin/sahara-api
END
    notifies :restart, "service[apache2]", :delayed
end

link "/etc/init.d/sahara" do
    action :create
    to "/lib/init/upstart-job"
end

service "sahara" do
    action [:enable, :start]
    restart_command "service sahara restart; sleep 5"
end

# Open the hadoop-required ports in the default security group
# In Juno, Sahara allows user to choose a security group in node-group-template; but not in Icehouse
bash "default-secgroup-enable-hadoop" do
    user "root"
    code <<-EOH
        . /root/adminrc
        for i in 8020 8021 11000 50010 50020 50030 50060 50070 50075 ; do
            nova secgroup-add-rule default tcp $i $i 0.0.0.0/0
        done
    EOH
    not_if ". /root/adminrc; nova secgroup-list-rules default | grep 8020"
end

bash "sahara-database-creation" do
    code <<-EOH
         mysql -uroot -p#{get_config('mysql-root-password')} -e "
                CREATE DATABASE #{node['bcpc']['dbname']['sahara']};
                GRANT ALL ON #{node['bcpc']['dbname']['sahara']}.* TO '#{get_config('mysql-sahara-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-sahara-password')}';
                GRANT ALL ON #{node['bcpc']['dbname']['sahara']}.* TO '#{get_config('mysql-sahara-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-sahara-password')}';
                FLUSH PRIVILEGES;"
         EOH
    not_if "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['sahara']}\"'|grep \"#{node['bcpc']['dbname']['sahara']}\""
    notifies :run, "bash[sahara-database-sync]", :immediately
end

bash "sahara-database-sync" do
    action :nothing
    user "root"
    code "sahara-db-manage upgrade head"
    notifies :restart, "service[sahara]", :immediately
end

# convert and upload sahara images
# If behind a proxy, put sahara image in /var/www of bootstrap node (or scp to headnode), and modify node['bcpc']['sahara']['vanilla_img_location']
remote_file "/tmp/sahara-icehouse-vanilla.qcow2" do
    source "#{node['bcpc']['sahara']['vanilla_img_location']}"
    owner "root"
    mode 00444
    not_if {File.exists?("/tmp/sahara-icehouse-vanilla.qcow2")}
end

bash "sahara-vanilla-image-conversion" do
    user "root"
    code "qemu-img convert -f qcow2 -O raw /tmp/sahara-icehouse-vanilla.qcow2 /tmp/sahara-icehouse-vanilla.img"
    not_if {File.exists?("/tmp/sahara-icehouse-vanilla.img")}
end

bash "sahara-vanilla-image-upload" do
    user "root"
    code <<-EOH
         . /root/adminrc
         glance image-create --name=sahara-icehouse-vanilla --disk-format=raw --container-format=bare --file /tmp/sahara-icehouse-vanilla.img
    EOH
    not_if ". /root/adminrc; glance image-list | grep 'sahara-icehouse-vanilla'"
end

bash "sahara-vanilla-image-register" do
    user "root"
    code <<-EOH
         . /root/adminrc
         IMAGE_ID=`glance image-list | grep "sahara-icehouse-vanilla" | cut -d'|' -f2 | tr -d ' '`
         sahara image-register --id $IMAGE_ID --username ubuntu
         sahara image-add-tag --tag vanilla --id $IMAGE_ID 
         sahara image-add-tag --tag "#{node['bcpc']['sahara']['vanilla_hadoop_version']}" --id $IMAGE_ID 
         sahara image-add-tag --tag "ubuntu" --id $IMAGE_ID
    EOH
    not_if ". /root/adminrc; sahara image-show --name sahara-icehouse-vanilla"
end

# create templates
ruby_block "sahara-create-master-vanilla-template" do
    block do
        ng_master = {:name => "sample-master-vanilla-template",
                     :flavor_id => "2",
                     :plugin_name => "vanilla",
                     :hadoop_version => node['bcpc']['sahara']['vanilla_hadoop_version'],
                     :node_processes => ["jobtracker", "namenode"],
                     :floating_ip_pool => node.chef_environment }

        `. /root/adminrc; echo '#{ng_master.to_json}' | sahara node-group-template-create`
    end
    not_if ". /root/adminrc; sahara node-group-template-list | grep 'sample-master-vanilla-template'"
end

ruby_block "sahara-create-worker-vanilla-template" do
    block do
        ng_worker = {:name => "sample-worker-vanilla-template",
                     :flavor_id => "2",
                     :plugin_name => "vanilla",
                     :hadoop_version => node['bcpc']['sahara']['vanilla_hadoop_version'],
                     :node_processes =>  ["tasktracker", "datanode"],
                     :floating_ip_pool => node.chef_environment }

        `. /root/adminrc; echo '#{ng_worker.to_json}' | sahara node-group-template-create`
    end
    not_if ". /root/adminrc; sahara node-group-template-list | grep 'sample-worker-vanilla-template'"
end

ruby_block "sahara-create-cluster-vanilla-template" do
    block do
        master_template_id = `. /root/adminrc; sahara node-group-template-show --name sample-master-vanilla-template | grep '| id' | cut -d '|' -f3 | tr -d ' '`
        worker_template_id = `. /root/adminrc; sahara node-group-template-show --name sample-worker-vanilla-template | grep '| id' | cut -d '|' -f3 | tr -d ' '`
        cluster = {:name => "sample-cluster-vanilla-template",
                   :plugin_name => "vanilla",
                   :hadoop_version => node['bcpc']['sahara']['vanilla_hadoop_version'],
                   :node_groups => [
                       {:name => "master",
                        :node_group_template_id => master_template_id.gsub("\n",""),
                        :count => 1 },
                       {:name => "workers",
                        :node_group_template_id => worker_template_id.gsub("\n",""),
                        :count => 2 }
                   ] }
        `. /root/adminrc; echo '#{cluster.to_json}' | sahara cluster-template-create`
    end
    not_if ". /root/adminrc; sahara cluster-template-list | grep 'sample-cluster-vanilla-template'"
end
