#
# Cookbook Name:: bcpc
# Recipe:: kibana
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

if node['bcpc']['enabled']['logging'] then

    include_recipe "bcpc::default"

    pkg = "kibana_#{node['bcpc']['kibana']['version']}_amd64.deb"

    cookbook_file "/tmp/#{pkg}" do
        source "bins/#{pkg}"
        owner "root"
        mode 00444
    end

    dpkg_package "kibana" do
        source "/tmp/#{pkg}"
        action :install
    end

    template "/opt/kibana/config/kibana.yml" do
        source "kibana-config.yml.erb"
        user "root"
        group "root"
        mode 00644
    end

    cookbook_file "kibana-upstart.conf" do
        action :create_if_missing
        mode 0644
        path "/etc/init/kibana.conf"
        owner "root"
        group "root"
        source "kibana-upstart.conf"
    end

    service "kibana" do
        provider Chef::Provider::Service::Upstart
        supports :status => true, :restart => true, :reload => false
        action [:enable, :start]
    end

end
