#
# Cookbook Name:: bcpc
# Recipe:: packages-common
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



# This recipe installs OS packages which are required by all node types.

package 'sshpass'  # GitHub #112 -- required for nodessh.sh 

# Remove spurious logging failures from this package
package "powernap" do
    action :remove
end

if node['bcpc']['enabled']['apt_upgrade'] then
    include_recipe "apt::default"
    bash "perform-upgrade" do
        user "root"
        code "DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" upgrade"
    end
end
