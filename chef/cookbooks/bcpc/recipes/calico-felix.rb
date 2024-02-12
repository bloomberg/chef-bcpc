# Cookbook:: bcpc
# Recipe:: calico-felix
#
# Copyright:: 2021 Bloomberg Finance L.P.
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

# 22.04 + HWE-edge kernel (now kernel 6.x) provides a bpftool which is
# linked against a newer version of libbpf that is incapable of loading
# BPF objects that Felix needs. To workaround this, install the non-HWE
# version of bpftool and have Felix use that one -- i.e., use the same
# bpftool that would be installed had we not selected the HWE kernel.
if Integer(node['kernel']['release'].split('.')[0]) == 6
  linux_tools_version = ''

  ruby_block 'Query the installed version of linux-tools-generic' do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      apt_query = "apt-cache show linux-tools-generic | awk -F ':' '/Version:/ {gsub(/ /, \"\", $2) ; print $2; exit}'"

      # The version in the path and the package are different...
      # The package has versions like x.y.z.m.n but the path to the
      # tool is found at x.y.z-m instead... so regex it is:
      linux_tools_version = shell_out(apt_query).stdout.chomp()
      linux_tools_version = linux_tools_version.split(/\.([^.]*)$/)[0]
      linux_tools_version = linux_tools_version.split(/\.([^.]*)$/).join('-')
    end
  end

  package 'linux-tools-generic' do
    action :upgrade
  end

  directory '/etc/systemd/system/calico-felix.service.d' do
    action :create
  end

  template '/etc/systemd/system/calico-felix.service.d/override.conf' do
    source 'calico/override.conf.erb'
    notifies :run, 'execute[reload systemd]', :immediately
    variables(
      linux_tools_version: lazy { linux_tools_version }
    )
  end

  execute 'reload systemd' do
    action :nothing
    command 'systemctl daemon-reload'
  end
end

package 'calico-felix' do
  action :upgrade
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
    cert_type: cert_type,
    failsafe_inbound: node['bcpc']['calico']['felix']['failsafe']['inbound'],
    failsafe_outbound: node['bcpc']['calico']['felix']['failsafe']['outbound']
  )
  notifies :restart, 'service[calico-felix]', :immediately
end
