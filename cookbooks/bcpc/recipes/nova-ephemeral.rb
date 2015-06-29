#
# Cookbook Name:: bcpc
# Recipe:: nova-ephemeral
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

ruby_block "setup-nova-ephemeral-config" do
  block do
    make_config('keystone-admin-token', secure_password)
    make_config('keystone-admin-user', "admin")
    make_config('keystone-admin-password', secure_password)
  end
end

cookbook_file "/tmp/nova-ephemeral.py" do
  source "nova-ephemeral.py"
  owner "root"
  mode 00755
end

template "/tmp/nova-ephemeral.sh" do
  user 'root'
  source "nova-ephemeral.sh.erb"
  owner "root"
  group "root"
  mode 0755
end

bash "nova-ephemeral-create" do
  user "root"
  code <<-EOH
    . /root/adminrc
    /tmp/nova-ephemeral.sh
  EOH
end

