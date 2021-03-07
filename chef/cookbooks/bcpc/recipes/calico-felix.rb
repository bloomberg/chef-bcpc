# Cookbook:: bcpc
# Recipe:: calico-felix
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

include_recipe 'bcpc::calico-apt'

package 'calico-felix' do
  action :upgrade
  options '--no-install-recommends'
end
service 'calico-felix'

# remove example felix cfg file
file '/etc/calico/felix.cfg.example' do
  action :delete
end

# determine cert type
cert_type = headnode? ? 'client-rw' : 'client-ro'

template '/etc/calico/calicoctl.cfg' do
  source 'calico/calicoctl.cfg.erb'
  variables(
    cert_type: cert_type
  )
end

template '/etc/calico/felix.cfg' do
  source 'calico/felix.cfg.erb'
  variables(
    cert_type: cert_type
  )
  notifies :restart, 'service[calico-felix]', :immediately
end
