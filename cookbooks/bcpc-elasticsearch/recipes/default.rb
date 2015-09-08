#
# Cookbook Name:: bcpc-elasticsearch
# Recipe:: default
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

if node['bcpc']['enabled']['logging']
    apt_repository 'elasticsearch' do
        uri node['bcpc']['repos']['elasticsearch']
        distribution 'stable'
        components ['main']
        key 'elasticsearch.key'
    end

    apt_preference 'elasticsearch' do
        pin          "version #{node['bcpc']['elasticsearch']['version']}"
        pin_priority '600'
    end

    package "openjdk-7-jre-headless" do
        action :install
    end

    package 'elasticsearch' do
        action :install
    end

    cookbook_file "/usr/local/bin/ess-shard-rebalancing" do
        source "ess-shard-rebalancing"
        owner "root"
        group "root"
        mode 00755
    end

    template "/etc/default/elasticsearch" do
        source "elasticsearch-default.erb"
        owner "root"
        group "root"
        mode 00644
        variables(
            :es_heap_size => node['bcpc']['elasticsearch']['heap_size'],
            :es_java_opts => node['bcpc']['elasticsearch']['java_opts']
        )
        notifies :restart, "service[elasticsearch]", :delayed
    end

    service "elasticsearch" do
        action [:enable, :start]
    end

    template "/etc/elasticsearch/elasticsearch.yml" do
        source "elasticsearch.yml.erb"
        owner "root"
        group "root"
        mode 00644
        variables(
          lazy {
            {
              :servers    => get_nodes_with_recipe('bcpc-elasticsearch'),
              :min_quorum => get_nodes_with_recipe('bcpc-elasticsearch').length/2 + 1
            }
          }
        )
        notifies :restart, "service[elasticsearch]", :immediately
    end

    directory "/usr/share/elasticsearch/plugins" do
        owner "root"
        group "root"
        mode 00755
    end

    cookbook_file "/tmp/elasticsearch-plugins.tgz" do
        source "elasticsearch-plugins.tgz"
        cookbook "bcpc-binary-files"
        owner "root"
        mode 00444
    end

    bash "install-elasticsearch-plugins" do
        code <<-EOH
            tar zxf /tmp/elasticsearch-plugins.tgz -C /usr/share/elasticsearch/plugins/
        EOH
        not_if "test -d /usr/share/elasticsearch/plugins/head"
    end

    package "curl" do
        action :upgrade
    end

    # TODO reconfigure for lazy evaluation
    bash "set-elasticsearch-replicas" do
        min_quorum = get_nodes_with_recipe('bcpc-elasticsearch').length/2 + 1
        code <<-EOH
            curl -XPUT '#{node['bcpc']['monitoring']['vip']}:9200/_settings' -d '
            {
                "index" : {
                    "number_of_replicas" : #{min_quorum-1}
                }
            }
            '
        EOH
    end

end
