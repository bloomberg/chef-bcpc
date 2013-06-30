#
# Cookbook Name:: bcpc
# Recipe:: beaver
#
# Copyright 2013, Bloomberg L.P.
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

include_recipe "bcpc::default"

%w{python-daemon python-pika python-boto python-redis python-zmq}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

%w{python-glob2_0.3-1_all.deb python-ujson_1.30-1_amd64.deb python-beaver_28-1_all.deb}.each do |pkg|
    cookbook_file "/tmp/#{pkg}" do
        source "bins/#{pkg}"
        owner "root"
        mode 00444
    end
    package "#{pkg}" do
        provider Chef::Provider::Package::Dpkg
        source "/tmp/#{pkg}"
        action :install
    end
end

user node[:bcpc][:beaver][:user] do
    shell "/bin/false"
    home "/var/log"
    gid node[:bcpc][:beaver][:group]
    system true
end

%w{/var/log/beaver /etc/beaver}.each do |dir|
    directory dir do
        owner node[:bcpc][:beaver][:user]
        group node[:bcpc][:beaver][:group]
        mode 00755
    end
end

template "/etc/beaver/beaver.conf" do
    source "beaver.conf.erb"
    owner node[:bcpc][:beaver][:user]
    group node[:bcpc][:beaver][:group]
    mode 00600
    notifies :restart, "service[beaver]", :delayed
end

template "/etc/init.d/beaver" do
    source "init.d-beaver.erb"
    owner node[:bcpc][:beaver][:user]
    group node[:bcpc][:beaver][:group]
    mode 00755
    notifies :restart, "service[beaver]", :delayed
end

template "/etc/cron.d/beaver" do
    source "cron-beaver.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[cron]", :delayed
end

service "beaver" do
    action [ :enable, :start ]
end
