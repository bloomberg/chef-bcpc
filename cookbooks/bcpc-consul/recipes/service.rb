#
# Cookbook Name:: bcpc-consul
# Recipe:: service
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

template '/etc/default/consul' do
  source 'service-default.erb'
  owner 'root'
  group 'root'
  mode 00644
  variables(
    'config_dir' => node['bcpc-consul']['conf_dir']
  )
  notifies :restart, 'service[consul]', :delayed
end

template '/lib/systemd/system/consul.service' do
  source 'consul.service.erb'
  owner 'root'
  group 'root'
  mode 00644
  variables(
    'executable' => node['bcpc-consul']['executable'],
    'conf_dir'   => node['bcpc-consul']['conf_dir'],
    'username'   => node['bcpc-consul']['username']
  )
  notifies :restart, 'service[consul]', :delayed
end

# Service parameters reference:
# https://www.consul.io/docs/agent/options.html
service_params = {
  'datacenter'           => node.chef_environment,
  'data_dir'             => node['bcpc-consul']['data_dir'],
  'disable_update_check' => true,
  'enable_script_checks' => true,
  'server'               => true,
  'log_level'            => node['bcpc-consul']['log_level'],
  'node_name'            => node['hostname'],
  'client_addr'          => node['bcpc-consul']['client_addr'],
  'addresses'            => node['bcpc-consul']['addresses'],
  'ports'                => node['bcpc-consul']['ports'],
  'advertise_addr'       => node['bcpc']['management']['ip'],
  'recursors'            => ["#{node['bcpc']['management']['vip']}:5300"]
}
headnodes = get_head_nodes
headnodes.delete(node)
if headnodes.length > 0
  peers = []
  headnodes.collect { |x| peers.push(x['bcpc']['management']['ip']) }
  service_params['retry_join'] = peers
end

# If data bag items exists, a leader has been manually selected for bootstrap
service_params['bootstrap'] = true unless config_defined('consul-bootstrapped')

template "#{node['bcpc-consul']['conf_dir']}/01base.json" do
  source 'config.json.erb'
  owner node['bcpc-consul']['username']
  group 'root'
  mode 00644
  variables(
    'config' => JSON.pretty_generate(service_params)
  )
  notifies :restart, 'service[consul]', :immediately
end

service 'consul' do
  supports status: true, restart: true, reload: true
  notifies :run, 'bash[consul-restart-wait]', :immediately
  action %i[enable]
end

# Wait for Consul election to complete before proceeding
bash 'consul-restart-wait' do
  action :nothing
  code <<-EOH
    curl -q \
    http://#{node['bcpc-consul']['client_addr']}:8500/v1/status/leader | \
    grep -q \:8300
  EOH
  retries 10
end

unless config_defined('consul-bootstrapped')
  ruby_block 'delay-for-consul-bootstrap' do
    block do
      sleep 15
    end
  end
  # Create data bag item to indicate we have a bootstrap leader
  ruby_block 'initialize-consul-bootstrap-flag' do
    block do
      make_config('consul-bootstrapped', true)
    end
    only_if do
      cmd = Mixlib::ShellOut.new('curl http://localhost:8500/v1/agent/members').run_command
      !cmd.error?
    end
  end
end
