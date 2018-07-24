#
# Cookbook Name:: bcpc
# Recipe:: packages_powerdns
#
# Copyright 2018, Bloomberg Finance L.P.
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

apt_repository 'powerdns' do
  uri node['bcpc']['repos']['powerdns']
  distribution 'xenial-auth-41'
  components ['main']
  key 'powerdns.key'
  notifies :run, 'execute[apt-get update]', :immediately
end

# We only stop unbound (if it exists) prior to fresh install of PDNS as the
# latter attempts to bind on conflicting port 53 during package install.
service 'unbound' do
  action :stop
  only_if 'test -f /usr/sbin/unbound'
  not_if 'test -f /usr/sbin/pdns_server'
end

# Kill dnsmasq (invoked by libvirtd) as it listens on :53 too.
bash 'kill-dnsmasq' do
  code 'pkill -TERM -f dnsmasq >/dev/null 2>&1 || true'
end

# Perform install only as upgrade process may need orchestrating.
package 'pdns-backend-mysql' do
  action :install
  notifies :stop, 'service[pdns]', :immediately
end

service 'pdns' do
  action :nothing
end

service 'unbound' do
  action :start
  only_if 'test -f /usr/sbin/unbound'
end
