# Cookbook:: bcpc
# Recipe:: common-packages
#
# Copyright:: 2021 Bloomberg Finance L.P.
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

package %w(
  lldpd
  ethtool
  bmon
  tshark
  nmap
  iperf
  curl
  conntrack
  dhcpdump
  traceroute
  fio
  bc
  iotop
  htop
  sysstat
  linux-tools-common
  sosreport
  python3-pip
  python3-memcache
  python3-mysqldb
  python3-six
  python3-ldap
  xinetd
  python3-openstackclient
  jq
  tmux
  crudini
  screen
  vim
  ksh
  bash-completion
)

cookbook_file '/etc/screenrc' do
  source 'screen/screenrc'
end

cookbook_file '/etc/vim/vimrc' do
  source 'vim/vimrc'
end
