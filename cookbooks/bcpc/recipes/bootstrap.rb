#
# Cookbook Name:: bcpc
# Recipe:: bootstrap
#
# Copyright 2014, Bloomberg Finance L.P.
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

#TODO: should extract prefix
#TODO: should declare dependency upon cobbler recipe

directory "/var/www/cobbler/pub/scripts" do
    action :create
    owner "root"
    group "adm"
    mode 02775
end

cookbook_file "/var/www/cobbler/pub/scripts/get-ssh-keys" do
    source "get-ssh-keys"
    owner "root"
    group "root"
    mode 00755
end

directory "/var/www/cobbler/pub/configs" do
    action :create
    owner "root"
    group "adm"
    mode 02775
end

template "/var/www/cobbler/pub/configs/wgetrc" do
    source "wgetrc.bootstrap.erb"
    owner "root"
    group "root"
    mode 00644
    variables(:http_proxy => node["bcpc"]["bootstrap"]["proxy"]) #maybe a Proc, what if attribute not defined?
end
