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

if node['bcpc']['enabled']['logging']
    apt_repository 'kibana' do
        uri node['bcpc']['repos']['kibana']
        distribution 'stable'
        components ['main']
        arch 'amd64'
        key 'elasticsearch.key'
    end

    package 'kibana' do
        action :upgrade
        options '-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"'
    end

    template "/opt/kibana/config/kibana.yml" do
        source "kibana-config.yml.erb"
        user "root"
        group "root"
        mode 00644
    end

    service "kibana" do
        provider Chef::Provider::Service::Init::Debian
        supports :status => true, :restart => true, :reload => false
        action [:enable, :start]
    end

    bash 'remove-old-kibana-upstart' do
        code <<-EOH
            stop kibana
            rm -f /etc/init/kibana.conf
        EOH
        only_if 'test -f /etc/init/kibana.conf'
    end
end
