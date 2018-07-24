#
# Cookbook Name:: bcpc
# Recipe:: apport
#
# Copyright 2016, Bloomberg Finance L.P.
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

package "apport" do
  action :install
end

template "/etc/default/apport" do
  source "etc_default_apport.erb"
  owner  "root"
  group  "root"
  mode   00644
  notifies :restart, "service[apport]", :delayed
end

service "apport" do
  action [:enable, :start]
end
