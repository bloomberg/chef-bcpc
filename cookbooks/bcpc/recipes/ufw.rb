#
# Cookbook Name:: bcpc
# Recipe:: ufw
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

package "ufw"

template "/etc/default/ufw" do
    source "ufw.erb"
    mode 00644
    notifies :restart, "service[ufw]", :delayed
end

template "/etc/ufw/sysctl.conf" do
    source "ufw.sysctl.conf.erb"
    mode 00644
    notifies :restart, "service[ufw]", :delayed
end

template "/etc/ufw/before.rules" do
    source "ufw.before.rules.erb"
    mode 00640
    notifies :restart, "service[ufw]", :delayed
end

bash "setup-allow-rules-ufw" do
    user "root"
    code <<-EOH
      ufw allow 22/tcp
      ufw allow 80/tcp
      ufw allow 443/tcp
      ufw allow 8080/tcp
      ufw allow in on #{node[:bcpc][:bootstrap][:pxe_interface]} from any port 68 to any port 67 proto udp
      ufw allow in on #{node[:bcpc][:bootstrap][:pxe_interface]} from any to #{node[:bcpc][:bootstrap][:server]} port tftp
      ufw --force enable
    EOH
    not_if "ufw status numbered | grep 22/tcp"
end

service "ufw" do
    action [ :enable, :start ]
end
