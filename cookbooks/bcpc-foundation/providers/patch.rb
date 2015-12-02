#
# Cookbook Name:: bcpc
# Provider:: patch
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

# expects the name of the file to stage and the cookbook (can be nil)
# returns the path to the staged file
def stage_file(file_to_stage, file_cookbook)
  path = ::File.join(Chef::Config[:file_cache_path], file_to_stage)
  cookbook = file_cookbook || cookbook_name

  Chef::Log.debug("creating #{path}")
  @file_patch_path = Chef::Resource::CookbookFile.new(path, run_context)
  @file_patch_path.source(file_to_stage)
  @file_patch_path.owner('root')
  @file_patch_path.mode(00644)
  @file_patch_path.cookbook(cookbook)
  @file_patch_path.run_action(:create)

  path
end

action :apply do
  # stage all files
  before_checksum_path = stage_file(new_resource.shasums_before_apply, new_resource.file_cookbook)
  after_checksum_path = stage_file(new_resource.shasums_after_apply, new_resource.file_cookbook)
  patch_path = stage_file(new_resource.patch_file, new_resource.file_cookbook)

  # test to see if checksums match
  before_cmd_str = "cd #{new_resource.patch_root_dir} && shasum -c #{before_checksum_path}"
  before_cmd = Mixlib::ShellOut.new(before_cmd_str).run_command

  after_cmd_str = "cd #{new_resource.patch_root_dir} && shasum -c #{after_checksum_path}"
  after_cmd = Mixlib::ShellOut.new(after_cmd_str).run_command

  # check stderr on before and after to find out if any files could not be found and raise if so
  if before_cmd.stderr.end_with?("could not be read\n")
    raise "Error reading files during before checksum: stdout: #{before_cmd.stdout}\nstderr:#{before_cmd.stderr}"
  end

  if after_cmd.stderr.end_with?("could not be read\n")
    raise "Error reading files during after checksum: stdout: #{after_cmd.stdout}\nstderr:#{after_cmd.stderr}"
  end

  if before_cmd.exitstatus == 0 and after_cmd.exitstatus > 0
    need_to_apply = true
  elsif before_cmd.exitstatus > 0 and after_cmd.exitstatus == 0
    need_to_apply = false
  elsif before_cmd.exitstatus == 0 and after_cmd.exitstatus == 0
    raise <<-EOH
      both before and after checksums matched, not a possible outcome
      BEFORE stdout: #{before_cmd.stdout}
      BEFORE stderr: #{before_cmd.stderr}
      AFTER stdout: #{after_cmd.stdout}
      AFTER stderr: #{after_cmd.stderr}
    EOH
  else
    raise <<-EOH
      errors raised by shasum both before and after:
      BEFORE: #{before_cmd.stderr}
      AFTER: #{after_cmd.stderr}
    EOH
  end

  next unless need_to_apply

  converge_by "apply patch #{new_resource.patch_file}" do
    patch_apply_cmd_str = <<-EOH
      cd #{new_resource.patch_root_dir}
      PREPATCH=$(patch -f -s --dry-run -p#{new_resource.patch_level} < '#{patch_path}' 2>&1)
      if [ $? -eq 0 ]; then
        patch -b -p#{new_resource.patch_level} < '#{patch_path}'
      else
        echo "$PREPATCH" >&2
        exit 1
      fi
    EOH

    patch_apply_cmd = Mixlib::ShellOut.new(patch_apply_cmd_str).run_command
    patch_apply_cmd.error!
  end
end
