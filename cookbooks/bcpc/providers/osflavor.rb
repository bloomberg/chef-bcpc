#
# Cookbook Name:: bcpc
# Provider:: osflavor
#
# Copyright 2016, Bloomberg Finance L.P.
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

action :create do
  need_to_delete = false
  need_to_converge = false
  args = openstack_cli
  stdout, stderr, status = Open3.capture3(*(args+ ["flavor", "show", @new_resource.name, "-f", "json"] ))
  if status.success?
    flavor_info = \
      if is_liberty?
        openstack_json_to_hash(JSON.parse(stdout))
      else
        JSON.parse(stdout)
      end

    # mapping of resource attribute names to flavor attributes
    {
      'disk' => :disk_gb,
      'ram' => :memory_mb,
      'OS-FLV-EXT-DATA:ephemeral' => :ephemeral_gb,
      'properties' => :properties,
      'swap' => :swap_gb,
      'vcpus' => :vcpus
    }.each do |flavor_attr, resource_attr|
      if flavor_attr == 'properties' and flavor_info[flavor_attr] != ""
        current_properties = {}
        flavor_info[flavor_attr].split(', ').each do |x|
          kv = x.split('=')
          current_properties[kv[0].to_s] = kv[1].to_s.gsub("'", '')
        end
        if current_properties != @new_resource.send(resource_attr)
          need_to_delete = true
          need_to_converge = true
        end
      # special callout for swap because the flavor provider translates 0 into ""
      # which we should consider equal to Fixnum 0 for comparison purposes
      elsif flavor_attr == 'swap' and flavor_info[flavor_attr] == "" and @new_resource.send(resource_attr) == 0
        ; # do nothing
      elsif flavor_info[flavor_attr] != @new_resource.send(resource_attr)
        need_to_delete = true
        need_to_converge = true
      end
    end
  else
    need_to_converge = true
  end

  if need_to_delete
    converge_by("Deleting #{@new_resource.name} before re-creation") do
      stdout, status = Open3.capture2( *(args + ["flavor", "delete", @new_resource.name]))
      Chef::Log.error "Failed to delete flavor before re-creation" unless status.success?
    end
  end

  if need_to_converge
    converge_by("Creating #{@new_resource.name}") do
      ispub = @new_resource.is_public ? "--public" : "--private"
      stdout, status = Open3.capture2( *(args + ["flavor", "create", "-f", "json",
                                                 "--ram=#{@new_resource.memory_mb}",
                                                 "--disk=#{@new_resource.disk_gb}",
                                                 "--ephemeral=#{@new_resource.ephemeral_gb}",
                                                 "--swap=#{@new_resource.swap_gb}",
                                                 "--vcpus=#{@new_resource.vcpus}",
                                                 "--id=#{@new_resource.flavor_id}",
                                                 "#{ispub}", @new_resource.name]
                                        ) )
      Chef::Log.error "Failed to create flavor: #{stdout} | #{stderr}" unless status.success?
    end
  end

  stdout, stderr, status = Open3.capture3(*(openstack_cli + ["flavor", "show", "-f", "json", "-c", "properties", @new_resource.name] ))
  if not status.success?
    Chef::Log.error "Failed to get flavor info: #{stdout} | #{stderr}"
    raise("Unable to get flavor info.")
  end

  line = JSON.parse(stdout)
  unless line.key?('properties')
    raise("No properties line in 'openstack flavor show'")
  end

  current_properties = {}
  line['properties'].split(', ').each do |x|
    kv = x.split('=')
    current_properties[kv[0].to_s] = kv[1].to_s.gsub("'", '')
  end
  new_properties = current_properties.clone
  @new_resource.properties.each { |k, v| new_properties[k.to_s] = v.to_s }

  args = []
  if current_properties != new_properties
    converge_by("Update flavor properties") do
      kvp = new_properties.collect { |k,v| args += ['--property', k + "=" + v] }
      stdout, stderr, status = Open3.capture3(*(openstack_cli + ["flavor", "set"] + args + [@new_resource.name]))
      Chef::Log.error "Failed to update flavor properties: #{stdout} | #{stderr}" unless status.success?
    end
  end
end

action :delete do
  stdout, stderr, status = Open3.capture3(*(openstack_cli +
                                            ["flavor", "show", @new_resource.name]))
  if status.success?
    converge_by("deleting #{new_resource.name}") do
      stdout, stderr, status = Open3.capture3(*(openstack_cli +
                                        ["flavor", "delete", @new_resource.name ] ))
      Chef::Log.error "Failed to delete flavor: #{stdout} | #{stderr}" unless status.success?
    end
  end
end
