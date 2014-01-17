#
# Cookbook Name:: bcpc
# Recipe:: fluentd
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

apt_repository "fluentd" do
    uri node['bcpc']['repos']['fluentd']
    distribution node['lsb']['codename']
    components ["contrib"]
end

package "td-agent" do
    action :upgrade
    options "--allow-unauthenticated"
end

bash "set-td-agent-user" do
    user "root"
    code "sed --in-place 's/^USER=td-agent.*/USER=root/' /etc/init.d/td-agent"
    only_if "grep -e '^USER=td-agent' /etc/init.d/td-agent"
    notifies :restart, "service[td-agent]", :delayed
end

# workaround for CHEF-3912 is to include versions from build_bins.sh
%w{elasticsearch!0.2.0 tail-multiline!0.1.5 tail-ex!0.1.1 record-reformer!0.1.1 rewrite!0.0.12}.each do |pkg|
    # split on the first exclaimation point to get the package name for Gem to look-up and the version for Gem
    gem_package "fluent-plugin-#{pkg.split('!',2)[0]}" do
        gem_binary "/usr/lib/fluent/ruby/bin/fluent-gem"
        version pkg.split('!',2)[1]
        options "--no-ri --no-rdoc --no-http-proxy --clear-sources --source #{get_binary_server_url}"
        action :install
    end
end

cookbook_file "/tmp/fluentd.patch" do
    source "fluentd.patch"
    owner "root"
    mode 00644
end

bash "patch-for-fluentd-plugin" do
    user "root"
    code <<-EOH
        cd /usr/lib/fluent/ruby/lib/ruby/gems/*/gems/fluent-plugin-elasticsearch-*/lib/fluent/plugin
        patch < /tmp/fluentd.patch
        cp /tmp/fluentd.patch .
    EOH
    not_if { File.exists?("/usr/lib/fluent/ruby/lib/ruby/gems/*/gems/fluent-plugin-elasticsearch-*/lib/fluent/plugin/fluentd.patch") }
    notifies :restart, "service[td-agent]", :delayed
end

template "/etc/td-agent/td-agent.conf" do
    source "fluentd-td-agent.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[td-agent]", :immediately
end

service "td-agent" do
    action [ :enable, :start ]
end
