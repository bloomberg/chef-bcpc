
# Cookbook Name:: bcpc
# Recipe:: cpupower
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

package "cpufrequtils" do
  action :purge
end

if node['bcpc']['hardware']['powersave']
  service 'ondemand' do
    action [:start, :enable]
  end
else
  service 'ondemand' do
    action [:stop, :disable]
  end

  # on VirtualBox there are no scaling governors, so exit peacefully
  bash 'enable CPU performance mode' do
    code <<-EOH
      if [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]
      then
        for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
        do
          echo performance > $CPUFREQ
        done
      fi
    EOH
  end
end
