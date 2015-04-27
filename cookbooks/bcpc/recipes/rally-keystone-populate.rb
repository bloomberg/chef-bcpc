#
# Cookbook Name:: bcpc
# Recipe:: keystone_populate
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


# keystone_populate.sh creates records in the db for service-* and endpoint-* records so that rally and other tools
# can function properly since templated backend services in our version of openstack do not support service-* and
# endpoint-* calls.

rally_user = node['bcpc']['rally']['user']

ruby_block "setup-rally-keystone-config" do
    block do
        make_config('keystone-admin-token', secure_password)
        make_config('keystone-admin-user', "admin")
        make_config('keystone-admin-password', secure_password)
    end
end

template "/tmp/keystone_populate.sh" do
    user 'root'
    source "keystone_populate.sh.erb"
    owner "#{rally_user}"
    group "#{rally_user}"
    mode 0755
end

bash "keystone-populate" do
    user "root"
    code <<-EOH
        /tmp/keystone_populate.sh
    EOH
    returns [0, 1]
end

