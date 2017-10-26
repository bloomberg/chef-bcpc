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

    systemd_unit 'routemon.service' do
      content <<-EOH.gsub(/^\s+/, '')
      [Unit]
      Description=Route monitor for network interfaces
      After=syslog.target network.target

      [Service]
      ExecStart=/usr/local/bin/routemon.pl \
        #{node['bcpc']['routemon']['numfixes']} \
        #{node['bcpc']['management']['interface']} \
        #{node['bcpc']['storage']['interface']}

      [Install]
      WantedBy=multi-user.target
      EOH
      action [:create, :enable]
    end

    cookbook_file "/usr/local/bin/routemon.pl" do
        source "routemon.pl"
        owner "root"
        mode 00755
        notifies :restart, "systemd_unit[routemon.service]", :immediately
    end

end
