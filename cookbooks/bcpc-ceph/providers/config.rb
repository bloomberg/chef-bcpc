#
# Cookbook Name:: bcpc
# Provider:: cephconfig
#
# Copyright 2015, Bloomberg Finance L.P.
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
  if Dir.exists?(@new_resource.path)
    Dir.chdir(@new_resource.path)
    f = Dir.glob((@new_resource.target) +".asok")
    f.each do |asok|
      path = ::File.join(@new_resource.path, asok)
      cmd = Mixlib::ShellOut.new("ceph daemon #{path} config get #{@new_resource.name}").run_command
      m = JSON.parse(cmd.stdout)
      if m.has_key? @new_resource.name
        if m[1] != @new_resource.value
          converge_by("setting ceph config") do
            set_cmd = Mixlib::ShellOut.new("ceph daemon #{path} config set #{@new_resource.name} #{@new_resource.value}").run_command
            if set_cmd.stdout.include?("\"success\"")
              Chef::Log.info("Ceph target \"#{asok}\" set #{@new_resource.name}:#{@new_resource.value}")
            else
              e = "Ceph target \"#{asok}\" unable to set #{@new_resource.name}:#{@new_resource.value}: #{set_cmd.stdout}"
              Chef::Log.error e
              raise e
            end
          end
        else
          Chef::Log.info("Ceph target \"#{asok}\" already set #{@new_resource.name}:#{@new_resource.value}")
        end
      else
        e = "Ceph target \"#{path}\" doesn't have the config value #{@new_resource.name}, got output #{m}"
        Chef::Log.error e
        raise e
      end
    end
  else
    Chef::Log.info("Ceph directory \"#{@new_resource.path}\" doesn't exist!")
  end
end
