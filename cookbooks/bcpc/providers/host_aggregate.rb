#
# Cookbook Name:: bcpc
# Provider:: host_aggregate
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
require 'open3'
require 'json'

def whyrun_supported?
  true
end

# calculate the hostname
# See bloomberg/chef-bcpc#1069
def hostname
  procfs_filename = '/proc/sys/kernel/hostname'
  @nodename ||= ::File.readable?(procfs_filename) ? ::File.open(procfs_filename) {|f| f.read.chomp } : node['hostname']
end

action :create do
  stdout, stderr, status = Open3.capture3(*(openstack_cli +
                                        ["aggregate", "show",
                                             @new_resource.name, "-f", "json" ]))

  if status.success?
    ha_fields = JSON.parse(stdout)
    current_properties =\
      if is_liberty?
        ha_fields.select {|x| x['Field'] == "properties"}[0]["Value"]
      else
        # in Mitaka properties are expressed as a string for some reason, e.g.
        # general_compute='yes', maintenance='no'"
        ha_fields['properties'].split(', ').each_with_object({}) do |x, memo|
          memo[x.split('=')[0]] = x.split('=')[1].gsub(/'/,'')
        end
      end

    # update metadata if needed
    new_properties = current_properties.clone
    @new_resource.metadata.each { |k,v| new_properties[k.to_s] = v.to_s }
    if new_properties != current_properties
      converge_by ("Update properties") do
        args = ["aggregate", "set", @new_resource.name]
        args += ["--zone", "#{@new_resource.zone}"] unless @new_resource.zone.nil?
        stdout, stderr, status = Open3.capture3( *(openstack_cli +
                             args + new_properties.collect {|k , v| ["--property", k + "=" + v ] }.flatten ))
        raise "Failed to update host aggregate #{@new_resource.name}: #{stderr}" unless status.success?
      end
    end
  else
    converge_by("Creating host aggregate #{new_resource.name}") do
      args = ["aggregate", "create", @new_resource.name , "-f", "json"]
      args += ["--zone", "#{@new_resource.zone}"] unless @new_resource.zone.nil?
      stdout, stderr, status = Open3.capture3( *(openstack_cli + args +
                                 @new_resource.metadata.collect {|k , v| ["--property", k.to_s + "=" + v.to_s ] }.flatten ))
      raise "Failed to create host aggregate #{@new_resource.name}: #{stderr}" unless status.success?
    end
  end
end

action :member do
  # Adds the current host to the host aggregate
  stdout, stderr, status = Open3.capture3(*(openstack_cli +
                                        ["aggregate", "show", @new_resource.name, "-f", "json" ]))
  raise "Unable to find host aggregate #{@new_resource.name}" unless status.success?

  ha_fields = JSON.parse(stdout)
  current_hosts = \
    if is_liberty?
      ha_fields.select {|x| x['Field'] == "hosts"}[0]["Value"]
    else
      ha_fields['hosts']
    end

  unless current_hosts.include?(hostname)
    converge_by ("Adding host") do
      stdout, stderr, status = Open3.capture3(*(openstack_cli +
                                ["aggregate", "add", "host", @new_resource.name, hostname ]))
      raise "Failed to add host #{hostname} to aggregate #{@new_resource.name}: #{stderr}" unless status.success?
    end
  end
end

action :depart do
  # Removes the current host from the host aggregate
  stdout, stderr, status = Open3.capture3(*(openstack_cli +
                                        ["aggregate", "show", @new_resource.name, "-f", "json" ]))
  raise "Unable to find host aggregate #{@new_resource.name}" unless status.success?

  ha_fields = JSON.parse(stdout)
  current_hosts = \
    if is_liberty?
      ha_fields.select {|x| x['Field'] == "hosts"}[0]["Value"]
    else
      ha_fields['hosts']
    end

  if current_hosts.include?(hostname)
    converge_by ("Removing host") do
      stdout, stderr, status = Open3.capture3(*(openstack_cli +
                                ["aggregate", "remove", "host", @new_resource.name, hostname ]))
      raise "Failed to remove host #{hostname} from aggregate #{@new_resource.name}: #{stderr}" unless status.success?
    end
  end
end
