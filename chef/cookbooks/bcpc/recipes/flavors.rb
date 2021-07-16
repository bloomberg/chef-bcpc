# Cookbook:: bcpc
# Recipe:: flavors
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

return unless node['bcpc']['openstack']['flavors']['enabled']

execute 'wait for flavors' do
  environment os_adminrc
  retries 30
  command 'openstack flavor list'
end

ruby_block 'collect openstack flavor list' do
  block do
    Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
    os_command = 'openstack flavor list --format json'
    os_command_out = shell_out(os_command, env: os_adminrc)
    flavors_list = JSON.parse(os_command_out.stdout)
    node.run_state['os_flavors'] = flavors_list.map { |f| f['Name'] }
  end
  action :run
end

node['bcpc']['openstack']['flavors'].each do |flavor, spec|
  # skip over the boolean we use to enable/disable this recipe
  next if flavor == 'enabled'
  execute "create #{flavor} flavor" do
    environment os_adminrc
    command <<-DOC
      openstack flavor create "#{flavor}" \
        --vcpus #{spec['vcpus']} \
        --ram #{spec['ram']} \
        --disk #{spec['disk']}
    DOC
    not_if { node.run_state['os_flavors'].include? flavor }
  end
end
