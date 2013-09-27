#
# Cookbook Name:: bcpc
# Recipe:: fluentd
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

%w{elasticsearch tail-multiline tail-ex record-reformer rewrite}.each do |pkg|
    cookbook_file "/tmp/fluent-plugin-#{pkg}.gem" do
        source "bins/fluent-plugin-#{pkg}.gem"
        owner "root"
        mode 00444
    end
    bash "install-fluent-plugin-#{pkg}" do
		code "/usr/lib/fluent/ruby/bin/fluent-gem install /tmp/fluent-plugin-#{pkg}.gem"
		not_if "/usr/lib/fluent/ruby/bin/fluent-gem list --local | grep fluent-plugin-#{pkg}"
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
    not_if "test -f /usr/lib/fluent/ruby/lib/ruby/gems/*/gems/fluent-plugin-elasticsearch-*/lib/fluent/plugin/fluentd.patch"
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
