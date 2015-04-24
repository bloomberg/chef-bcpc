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
  ondemand_tunable_dir = ::File.join(base_cpu_dir, 'cpufreq', 'ondemand')

  unless ::File.exists?(cpu0_gov_file)
    Chef::Log.warn("\nCurrent platform hardware/OS combination does not support CPU scaling governors")
    next
  end

  # since we have several resources that may be changed, iterate through them and get their values, pushing
  # any that need updated onto this list
  unconverged_resources = []

  begin
    current_governor = ::File.read(cpu0_gov_file).chomp
    unconverged_resources.push('governor') if current_governor != @new_resource.governor
  rescue Errno::ENOENT
    Chef::Log.warn("\nThis system is misconfigured and is missing a scaling governor at #{cpu0_gov_file}, please configure the power profile in the BIOS for OS control")
  end

  # TODO: short-circuit out here if ondemand_tunable_dir doesn't exist)
  %w{ondemand_ignore_nice_load
     ondemand_io_is_busy
     ondemand_powersave_bias
     ondemand_sampling_down_factor
     ondemand_sampling_rate
     ondemand_sampling_rate_min
     ondemand_up_threshold}.each do |ondemand_tunable|
    tunable = @new_resource.send(ondemand_tunable)
    unless tunable.nil? or tunable.empty?
      tunable_file_name = ondemand_tunable.gsub(/^ondemand_/, '')
      tunable_path = ::File.join(ondemand_tunable_dir, tunable_file_name)
      begin
        current_tunable = ::File.read(tunable_path).chomp
        unconverged_resources.push(ondemand_tunable) if current_tunable.to_i != tunable
      rescue Error::ENOENT
        Chef::Log.warn("\nThis system is misconfigured and is missing the ondemand scaling governor tunable #{tunable_file_name}")
      end
    end
  end

  unless ::File.exists?(cpu0_all_govs_file)
    raise("Your system is seriously broken because you have a CPU scaling governor active but no available list of scaling governors")
  end
  
  available_governors = ::File.read(cpu0_all_govs_file).chomp.split
  
  unless available_governors.include?(@new_resource.governor)
    raise("Requested governor #{@new_resource.governor} not an available CPU scaling governor (available governors: #{available_governors.join(', ')})")
  end

  # next out of the block here so that Chef records the resource as being up to date if no changes are needed
  next unless unconverged_resources.length > 0

  converge_by("set CPU scaling governor to #{@new_resource.governor}") do
    # set CPU scaling governor, failing nicely if system configuration is weird and one or more governors are missing (complete with helpful error message!)
    cpus = Dir.entries(base_cpu_dir).select { |entry| entry =~ /cpu[0-9]+/ }
    cpu_governor_paths = cpus.map { |cpu| ::File.join(base_cpu_dir, cpu, 'cpufreq', 'scaling_governor') }
    cpu_governor_paths.each do |cpu_governor_path|
      begin
        ::File.open(cpu_governor_path, 'w') do |governor|
          governor.write @new_resource.governor
        end
      rescue Errno::ENOENT
        Chef::Log.warn("\nThis system is misconfigured and is missing a scaling governor at #{cpu_governor_path}, please configure the power profile in the BIOS for OS control")
      end
    end

    # walk through the ondemand tunable attributes, setting any that are provided in the resource and ignoring those that are not
    # TODO: short-circuit out here if ondemand_tunable_dir doesn't exist)
    %w{ondemand_ignore_nice_load
       ondemand_io_is_busy
       ondemand_powersave_bias
       ondemand_sampling_down_factor
       ondemand_sampling_rate
       ondemand_sampling_rate_min
       ondemand_up_threshold}.each do |ondemand_tunable|
      tunable = @new_resource.send(ondemand_tunable)
      unless tunable.nil? or tunable.empty?
        tunable_file_name = ondemand_tunable.gsub(/^ondemand_/, '')
        tunable_path = ::File.join(ondemand_tunable_dir, tunable_file_name)
        begin
          ::File.open(tunable_path, 'w') do |f|
            f.write tunable.to_s
          end
        rescue Error::ENOENT
          Chef::Log.warn("\nThis system is misconfigured and is missing the ondemand scaling governor tunable #{tunable_file_name}")
        end
      end
    end
  end
end
