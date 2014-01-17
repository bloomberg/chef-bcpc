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

include_recipe "bcpc::default"
include_recipe "bcpc::apache2"

remote_file "/tmp/kibana3.tgz" do
    source "#{get_binary_server_url}/kibana3.tgz"
    owner "root"
    mode 00444
    not_if { Dir.exists? "/opt/kibana3" }
end

bash "install-kibana" do
    code <<-EOH
        tar zxf /tmp/kibana3.tgz -C /opt/
    EOH
    not_if { Dir.exists? "/opt/kibana3" }
end

template "/opt/kibana3/config.js" do
    source "kibana-config.js.erb"
    user "root"
    group "root"
    mode 00644
end

template "/etc/apache2/sites-available/kibana-web" do
    source "apache-kibana-web.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end

bash "apache-enable-kibana-web" do
    user "root"
    code "a2ensite kibana-web"
    not_if "test -r /etc/apache2/sites-enabled/kibana-web"
    notifies :restart, "service[apache2]", :delayed
end
