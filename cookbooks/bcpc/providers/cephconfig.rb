#
# Cookbook Name:: bcpc
# Provider:: cephconfig
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

def whyrun_supported?
  true
end

action :set do
  Dir.chdir(@new_resource.path)
  f = Dir.glob((@new_resource.target) +".asok")
  f.each do |asok|
    cmd = Mixlib::ShellOut.new("ceph daemon #{@new_resource.path}/#{asok} config get  #{@new_resource.name}").run_command
    m = /\s*\{ \"#{@new_resource.name}\"\: \"(.*)\"\}/.match(cmd.stdout)
    if m
      if m[1] != @new_resource.value
        converge_by("setting ceph config") do
          set_cmd = Mixlib::ShellOut.new("ceph daemon #{@new_resource.path}/#{asok} config set #{@new_resource.name} #{@new_resource.value}").run_command
          if set_cmd.stdout.include?("\"success\"")
            Chef::Log.info("Ceph target \"#{asok}\" set #{new_resource.name}:#{new_resource.value}")     
          else
            Chef::Log.error("Ceph target \"#{asok}\" unable to set  #{new_resource.name}:#{new_resource.value}: #{seet_cmd.stdout}")  
            raise "Ceph target \"#{asok}\" unable to set  #{new_resource.name}:#{new_resource.value}: #{seet_cmd.stdout}"
          end
        end
      else
        Chef::Log.info("Ceph target \"#{asok}\" already set #{new_resource.name}:#{new_resource.value}")     
      end
    else      
      Chef::Log.error("Ceph target \"#{@new_resource.path}/#{asok}\" doesn't have the config value #{new_resource.name}")
      raise "Ceph target \"#{@new_resource.path}/#{asok}\" doesn't have the config value #{new_resource.name}"
    end
  end
end


