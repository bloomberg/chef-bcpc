#
# Cookbook Name:: bcpc
# Provider:: cpupower
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
  # get the current CPU governor on CPU0 (considered representative)
  base_cpu_dir = ::File.join('/', 'sys', 'devices', 'system', 'cpu')
  cpu0_gov_file = ::File.join(base_cpu_dir, 'cpu0', 'cpufreq', 'scaling_governor')
  cpu0_all_govs_file = ::File.join(base_cpu_dir, 'cpu0', 'cpufreq', 'scaling_available_governors')
  
  unless ::File.exists?(cpu0_gov_file)
    Chef::Log.warn("\nCurrent platform hardware/OS combination does not support CPU scaling governors")
    next
  end
  
  current_governor = ::File.read(cpu0_gov_file).chomp
  # next out of the block here so that Chef records the resource as being up to date if no change is needed
  next if current_governor == @new_resource.governor

  unless ::File.exists?(cpu0_all_govs_file)
    raise("Your system is seriously broken because you have a CPU scaling governor active but no available list of scaling governors")
  end
  
  available_governors = ::File.read(cpu0_all_govs_file).chomp.split
  
  unless available_governors.include?(@new_resource.governor)
    raise("Requested governor #{@new_resource.governor} not an available CPU scaling governor (available governors: #{available_governors.join(', ')})")
  end
  
  converge_by("set CPU scaling governor to #{@new_resource.governor}") do
    cpus = Dir.entries(base_cpu_dir).select { |entry| entry =~ /cpu[0-9]+/ }
    cpu_governor_paths = cpus.map { |cpu| ::File.join(base_cpu_dir, cpu, 'cpufreq', 'scaling_governor') }
    cpu_governor_paths.each do |cpu_governor_path|
      ::File.open(cpu_governor_path, 'w') do |governor|
        governor.write @new_resource.governor
      end
    end
  end
end
