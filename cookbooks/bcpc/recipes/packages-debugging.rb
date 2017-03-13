#
# Cookbook Name:: bcpc
# Recipe:: packages-debugging
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


# PURPOSE:
# This recipe installs packages which are useful for debugging the stack
# and troubleshooting system issues. Packages should not be included here
# if the stack itself depends on them for its normal operation.

# Network troubleshooting tools
package "ethtool"
package "bmon"
package "tshark"
package "nmap"
package "iperf"
package "curl"
package "conntrack"
package "dhcpdump"

# I/O troubleshooting tools
package "fio"
package "bc"
package "iotop"

# System troubleshooting tools
package "htop"

package "sysstat"

if node['bcpc']['enabled']['sysstat']
  bash "enable-sysstat" do
    user 'root'
    code 'sed -i "s|^ENABLED=\"false\"|ENABLED=\"true\"|" /etc/default/sysstat'
  end
end

package "linux-tools-common"
package "linux-tools-#{node['kernel']['release']}"

package "sosreport"

# Remove backports repository from Trusty builds since sosreport is now
# available in trusty/main
apt_repository "backports" do
  action :remove
end
