#
# Cookbook Name:: bcpc
# Recipe:: networking_functions
#
# Copyright 2017, Bloomberg Finance L.P.
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

if node['bcpc']['monitoring']['provider']
  function = 'ipset-monitoring'
  # ipset is used to maintain largish block(s) of IP addresses to be referred
  # to by iptables
  package 'ipset'

  # Insert numbering so it runs before /etc/network/if-up.d/bcpc-firewall
  template "/etc/network/if-up.d/001bcpc-#{function}" do
    mode 775
    source "bcpc-#{function}.erb"
    notifies :run, "execute[run-#{function}-script]", :delayed
  end

  template "/etc/#{function}-clients.conf" do
    mode 600
    source "#{function}-clients.conf.erb"
    variables(
      :clients => node['bcpc']['monitoring']['external_clients'].sort
    )
    notifies :run, "execute[run-#{function}-script]", :immediately
  end

  execute "run-#{function}-script" do
    action :nothing
    command "/etc/network/if-up.d/001bcpc-#{function}"
  end

end

network_functions = ['firewall']
if node['bcpc']['enabled']['neutron']
  network_functions += ['l3-routing']
else
  network_functions += ['routing']
end
network_functions.each do |function|
  template "/etc/network/if-up.d/bcpc-#{function}" do
    mode 775
    source "bcpc-#{function}.erb"
    notifies :run, "execute[run-#{function}-script-once]", :immediately
  end

  execute "run-#{function}-script-once" do
    action :nothing
    command "/etc/network/if-up.d/bcpc-#{function}"
  end
end
