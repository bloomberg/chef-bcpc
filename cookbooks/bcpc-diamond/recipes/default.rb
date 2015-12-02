#
# Cookbook Name:: bcpc-diamond
# Recipe:: default
#
# Copyright 2015, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
if node['bcpc']['enabled']['metrics']
    cookbook_file "/tmp/diamond.deb" do
        source "diamond.deb"
        cookbook "bcpc-binary-files"
        owner "root"
        mode 00444
    end

    %w{python-support python-configobj python-pip python-httplib2}.each do |pkg|
        package pkg do
            action :upgrade
        end
    end

    package "diamond" do
        provider Chef::Provider::Package::Dpkg
        source "/tmp/diamond.deb"
        action :upgrade
        options "--force-confold --force-confdef"
    end

    if node['bcpc']['virt_type'] == "kvm"
        package "ipmitool" do
            action :upgrade
        end
        package "smartmontools" do
            action :upgrade
        end
    end

    cookbook_file "/tmp/pyrabbit-1.0.1.tar.gz" do
        source "pyrabbit-1.0.1.tar.gz"
        cookbook "bcpc-binary-files"
        owner "root"
        mode 00444
    end

    bash "install-pyrabbit" do
        code <<-EOH
            pip install /tmp/pyrabbit-1.0.1.tar.gz
        EOH
        not_if "pip freeze|grep pyrabbit"
    end

    bash "diamond-set-user" do
        user "root"
        code <<-EOH
            sed --in-place '/^DIAMOND_USER=/d' /etc/default/diamond
            echo 'DIAMOND_USER="root"' >> /etc/default/diamond
        EOH
        not_if "grep -e '^DIAMOND_USER=\"root\"' /etc/default/diamond"
        notifies :restart, "service[diamond]", :delayed
    end

    template "/etc/diamond/diamond.conf" do
        source "diamond.conf.erb"
        owner "diamond"
        group "root"
        mode 00600
        variables(
          lazy {
            {:servers => get_head_nodes}
          }
        )
        notifies :restart, "service[diamond]", :delayed
    end

    template "/etc/diamond/collectors/ElasticSearchCollector.conf" do
        source "diamond-collector-elasticsearch.conf.erb"
        owner "diamond"
        group "root"
        mode 00600
        notifies :restart, "service[diamond]", :delayed
        only_if "test -f /etc/init.d/elasticsearch"
    end

    directory "/usr/share/diamond/collectors/cephpools" do
        owner "root"
        group "root"
        mode 00755
    end

    cookbook_file "/usr/share/diamond/collectors/cephpools/cephpools.py" do
        source "diamond-collector-cephpools.py"
        owner "root"
        group "root"
        mode 00644
    end

    %w{CephPoolStatsCollector CephCollector}.each do |collector|
        template "/etc/diamond/collectors/#{collector}.conf" do
            source "diamond-collector.conf.erb"
            owner "diamond"
            group "root"
            mode 00600
            variables(
                :parameters => node['bcpc']['diamond']['collectors'][collector]
            )
            notifies :restart, "service[diamond]", :delayed
            only_if "test -d /var/lib/ceph/mon/ceph-#{node['hostname']}"
        end
    end

    directory '/usr/share/diamond/collectors/Cloud/' do
        owner 'root'
        group 'root'
        mode 00755
        action :create
    end

    cookbook_file "/usr/share/diamond/collectors/Cloud/CloudCollector.py" do
        source "diamond-collector-cloud-openstack.py"
        owner "root"
        mode 00644
    end

    template "/etc/diamond/collectors/CloudCollector.conf" do
        source "diamond-collector.conf.erb"
        owner "diamond"
        group "root"
        mode 00600
        variables(lazy {
          {:parameters => node['bcpc']['diamond']['collectors']['cloud'].merge(
              "db_user" => get_config('mysql-root-user'),
              "db_password" => get_config('mysql-root-password'),
          )}
        })
        notifies :restart, "service[diamond]", :delayed
        only_if "test -d /var/lib/mysql/nova"
    end

    service "diamond" do
        action [:enable, :start]
    end
end
