#
# Cookbook Name:: bcpc
# Recipe:: tpm
#
# Copyright 2014, Bloomberg Finance L.P.
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
include_recipe "bcpc::default"

package "rng-tools"
package "tpm-tools"
package "trousers"

service "rng-tools" do
  action :stop
end

execute "rngd-test" do
  ignore_failure true
  command "rm -f /tmp/tpmfailed && rngd -f --hrng=tpm --fill-watermark=90% --feed-interval=1 || touch /tmp/tpmfailed"
  timeout 3
end

bash "enable-tpm" do
  user "root"
  code <<-EOH
       if [[ ! -f /etc/default/rng-tools.orig ]]; then cp /etc/default/rng-tools /etc/default/rng-tools.orig ; fi
       sed -i -e '/^#RNG.*tpm.*/s/^#//' /etc/default/rng-tools 
       sed -i -e '/^#HRNGD.*null/s/^#//' /etc/default/rng-tools 
  EOH
  not_if "ls /tmp/tpmfailed"
end


service "rng-tools" do
  action :start
  not_if "ls /tmp/tpmfailed"
end



