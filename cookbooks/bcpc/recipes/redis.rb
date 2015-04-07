#
# Cookbook Name:: bcpc
# Recipe:: redis
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

%w{redis-server python-hiredis python-redis}.each do |pkg|
    apt_repository pkg do
        uri node['bcpc']['repos'][pkg]
        distribution node['lsb']['codename']
        components ["main"]
        key "redis.key"
    end
    package pkg do
        action :upgrade
    end
end

template "/etc/redis/redis.conf" do
    source "redis.conf.erb"
    mode 00640
    owner "redis"
    group "redis"
    variables(
        :port => 6379,
        :count => ""
    )
    notifies :restart, "service[redis-server]", :immediately
end

service "redis-server" do
    action [:enable, :start]
end
