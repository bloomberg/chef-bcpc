#
# Cookbook Name:: bcpc
# Provider:: flavor_access
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

action :add do
  cur_proj = Array.new
  project_id_list = Array.new
  acl_add = Array.new
  #Verify Flavor Exists and is Private
  stdout, stderr, status = Open3.capture3(*(nova_cli + ["flavor-access-list", "--flavor",  @new_resource.flavor_name] ))
  if status.success?
    stdout.split("\n").each do | fline |
      cur_proj << (fline.split("|")[2]).strip if fline.match(/(\w+\-){4}\w+/)
    end
  end
  if not status.success?
    Chef::Log.error "Flavor #{new_resource.flavor_name}, does not exist or is not private: #{stdout} | #{stderr}"
    raise("Flavor, #{new_resource.flavor_name}, does not exist or is not private.")
  end
  @new_resource.project_desc.each do | pdesname |
#    Get project ID from Project Descriptoin
    stdout, stderr, status = Open3.capture3(*(openstack_cli + ["project", "list", "--long", "-f", "json"] ))
    if status.success?
      proj_info = JSON.parse(stdout)
      proj_info.each do |phash|
        project_id_list.push(phash['ID']) if pdesname.eql? phash['Description']
      end
    end
    if not status.success?
      Chef::Log.error "Failed to get project list info: #{stdout} | #{stderr}"
      raise("Unable to list projects.")
    end
  end

  acl_add = project_id_list - cur_proj
  
  unless acl_add.empty?
    converge_by("Add Flavor Access") do 
      acl_add.each do | proj |
        stdout, stderr, status = Open3.capture3(*(nova_cli + ["flavor-access-add",  @new_resource.flavor_name, proj] ))
        Chef::Log.error "Failed to add flavor access: #{stdout} | #{stderr}" unless status.success?
      end
    end   
  end
end

