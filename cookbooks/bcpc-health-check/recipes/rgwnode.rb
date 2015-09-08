#
# Cookbook Name:: bcpc-health-check
# Recipe:: rgwnode
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

include_recipe 'bcpc-health-check'

%w{rgw}.each do |cc|
  template  "/usr/local/etc/checks/#{cc}.yml" do
    source "#{cc}.yml.erb"
    owner "root"
    group "root"
    mode 00640
  end

  cookbook_file "/usr/local/bin/checks/#{cc}" do
    source cc
    owner "root"
    mode "00755"
  end

  # this requires the Zabbix agent to be installed
  cron "check-#{cc}" do
    home "/var/lib/zabbix"
    user "root"
    minute "*/10"
    path "/usr/local/bin:/usr/bin:/bin"
    command "zabbix_sender -c /etc/zabbix/zabbix_agentd.conf --key 'check.#{cc}' --value `check -f timeonly #{cc}` 2>&1 | /usr/bin/logger -p local0.notice"
    only_if { node['bcpc']['enabled']['monitoring'] }
  end

  ruby_block "zabbix_bucket_stats-runtime-wrapper" do
    block do
      template "/usr/local/bin/zabbix_bucket_stats" do
        source "zabbix_bucket_stats.erb"
        cookbook 'bcpc-zabbix'
        owner "root"
        group "root"
        mode "00755"
        only_if { get_cached_head_node_names.include?(node['hostname']) }
      end
    end
  end
end
