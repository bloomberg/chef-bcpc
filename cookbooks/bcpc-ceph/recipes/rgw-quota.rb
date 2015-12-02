# Cookbook Name:: bcpc-ceph
# Recipe:: rgw-quota
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

cookbook_file '/usr/local/bin/set-rgw-quota.py' do
    source 'set-rgw-quota.py'
    owner 'root'
    mode 00755
end

execute 'set-rgw-quota' do
    action :nothing
    command '/usr/local/bin/set-rgw-quota.py'
end

template '/usr/local/etc/rgw-quota.yml' do
    source 'rgw-quota.yml.erb'
    owner 'root'
    mode 00644
    variables(
        :quotas => node['bcpc']['rgw_quota'].to_hash.to_yaml
    )
    notifies :run, 'execute[set-rgw-quota]', :immediately
end

cron 'set-rgw-quota' do
    minute '*/15'
    hour '*'
    user 'root'
    command '/usr/local/bin/if_vip /usr/local/bin/set-rgw-quota.py'
end
