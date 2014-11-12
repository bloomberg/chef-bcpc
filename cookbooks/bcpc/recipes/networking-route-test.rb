#
# Cookbook Name:: bcpc
# Recipe:: networking-route-test
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

if node['bcpc']['enabled']['network_tests'] then

    cookbook_file "/usr/local/bin/routemon.pl" do
        source "routemon.pl"
        owner "root"
        mode 00755
    end

    template "/etc/init/routemon.conf" do
        source "routemon.conf.erb"
        owner "root"
        mode "0644"
    end

    service "routemon" do
        provider Chef::Provider::Service::Upstart
        action :start
    end

end
