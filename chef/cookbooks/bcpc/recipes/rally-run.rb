# This recipe runs the rally after rally and rally-deploments recipes are done
# up to be able to be ran.
#
# Cookbook Name:: bcpc
# Recipe:: rally-run
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

rally_user = node['bcpc']['rally']['user']
rally_home_dir = node['etc']['passwd'][rally_user]['dir']
rally_install_dir = "#{rally_home_dir}/rally"
rally_venv_dir = "#{rally_install_dir}/venv"
rally_deployment = "v3"

bash "run rally" do
  code <<-EOH
    cd #{rally_install_dir}/bb-rally
    source #{rally_venv_dir}/bin/activate
    rally deployment use #{rally_deployment}
    rally task start --task-args-file cluster_configs/#{node.chef_environment}.yaml --task scenarios/sanity.yaml
    if rally task sla-check | grep -c "FAIL"; then
      report_name=sanity-$(date +"%Y%m%d%H%M%S").html
      rally task report --out $report_name
      echo "Sanity check failed, please examine the rally report $report_name"
      exit 1
    fi
  EOH
  user rally_user
end
