#
# Cookbook Name:: bcpc
# Recipe:: logstash
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

cookbook_file "/opt/logstash-1.1.9-monolithic.jar" do
    source "bins/logstash-1.1.9-monolithic.jar"
    owner "root"
    mode 00644
end

link "/opt/logstash.jar" do
    to "/opt/logstash-1.1.9-monolithic.jar"
    notifies :restart, "service[logstash]", :delayed
end

user node[:bcpc][:logstash][:user] do
    shell "/bin/false"
    home "/var/log"
    gid node[:bcpc][:logstash][:group]
    system true
end

directory "/var/log/logstash" do
    user node[:bcpc][:logstash][:user]
    group node[:bcpc][:logstash][:group]
    mode 00755
end

directory "/var/lib/logstash" do
    user node[:bcpc][:logstash][:user]
    group node[:bcpc][:logstash][:group]
    mode 00755
end

template "/etc/init/logstash.conf" do
    source "upstart-logstash.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[logstash]", :delayed
end

template "/etc/logstash.conf" do
    source "logstash.conf.erb"
    owner node[:bcpc][:logstash][:user]
    group "root"
    mode 00600
    notifies :restart, "service[logstash]", :delayed
end

package "libzmq1"

link "/usr/local/lib/libzmq.so" do
    to "/usr/lib/libzmq.so.1"
    notifies :restart, "service[logstash]", :delayed
end

service "logstash" do
    provider Chef::Provider::Service::Upstart
    action [ :enable, :start ]
end
