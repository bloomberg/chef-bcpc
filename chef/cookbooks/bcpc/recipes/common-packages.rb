# Cookbook:: bcpc
# Recipe:: common-packages
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

# system related packages
package 'lldpd'

# Network troubleshooting tools
package 'ethtool'
package 'bmon'
package 'tshark'
package 'nmap'
package 'iperf'
package 'curl'
package 'conntrack'
package 'dhcpdump'
package 'traceroute'

# I/O troubleshooting tools
package 'fio'
package 'bc'
package 'iotop'

# System troubleshooting tools
package 'htop'
package 'sysstat'
package 'linux-tools-common'
package 'sosreport'

# various python packages
package 'python-pip'
package 'python-memcache'
package 'python-mysqldb'
package 'python-six'
package 'python-ldap'
package 'python-configparser'

# used for monitoring various services
package 'xinetd'

# openstack client cli
package 'python-openstackclient'

# packages used for operatons and file edits
package 'jq'
package 'tmux'
package 'crudini'

package 'screen'
cookbook_file '/etc/screenrc' do
  source 'screen/screenrc'
end

package 'vim'
cookbook_file '/etc/vim/vimrc' do
  source 'vim/vimrc'
end

# some people like kornshell ¯\_(ツ)_/¯
package 'ksh'

# bash completion for operators
package 'bash-completion'
