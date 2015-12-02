#
# Cookbook Name:: bcpc-haproxy
# Recipe:: monitornode
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

include_recipe "bcpc-haproxy"

ruby_block "initialize-haproxy-monitoring-config" do
  block do
    salt = secure_password_alphanum_upper(2)
    mon_adm_pw = secure_password
    make_config('monitoring-admin-user', "monitoring_admin")
    make_config('monitoring-admin-password', mon_adm_pw)
    make_config('monitoring-admin-password-hash', mon_adm_pw.crypt('$6$' + salt))
  end
end

template "/etc/haproxy/haproxy.cfg" do
  source "haproxy-monitoring.cfg.erb"
  mode 00644
  variables(
    lazy {
      {
        :monitoring_admin_username => get_config("monitoring-admin-user"),
        :monitoring_admin_password_hash => get_config("monitoring-admin-password-hash"),
        :servers => get_monitor_nodes
      }
    }
  )
  notifies :restart, "service[haproxy]", :immediately
end
