# Cookbook:: bcpc
# Recipe:: unbound
#
# Copyright:: 2020 Bloomberg Finance L.P.
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

pdns_attr = node['bcpc']['powerdns']
local_zones_conf = '/etc/unbound/unbound.conf.d/local-zones.conf'
service 'unbound'

# if pdns is not enabled, then we should remove the local_zones_conf file
# that was installed from previous installations
unless pdns_attr['enabled']
  file local_zones_conf do
    action :delete
    notifies :restart, 'service[unbound]', :immediately
  end
end

return unless pdns_attr['enabled']

begin
  powerdns_address = pdns_attr['local_address']
  powerdns_port = pdns_attr['local_port']
  powerdns_ns = "#{powerdns_address}@#{powerdns_port}"
  local_zones = {}
  networks = node['bcpc']['neutron']['networks'].dup

  networks.each do |network|
    %w(fixed float).each do |type|
      next unless network[type]['dns-zones']['create']
      network[type].fetch('subnets', []).each do |subnet|
        zones = cidr_to_reverse_zones(IPAddress(subnet['allocation']))
        zones.each do |z|
          local_zones[z['zone']] = powerdns_ns
        end
      end
    end
  end

  template local_zones_conf do
    source 'unbound/local-zones.conf.erb'
    variables(
      local_zones: local_zones
    )
    notifies :restart, 'service[unbound]', :delayed
  end
end
