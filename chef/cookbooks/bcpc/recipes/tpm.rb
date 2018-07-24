#
# Cookbook Name:: bcpc
# Recipe:: tpm
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

return unless node['bcpc']['enabled']['tpm']

include_recipe "bcpc::default"

package "linux-image-extra-#{node['kernel']['release']}"

# this is the sort of thing that you wish didn't have to exist, but it does,
# because trousers has a broken postinst script
bash "work-around-broken-trousers-postinst" do
  code <<-EOH
    cd /tmp && apt-get download trousers
    if [[ $? != 0 ]]; then exit 1; fi
    TROUSERS_PKG=$(find . -maxdepth 1 -name trousers\*deb)
    dpkg --unpack $TROUSERS_PKG
    sed -i 's/pidof udevd/pidof systemd-udevd/g' /var/lib/dpkg/info/trousers.postinst
    dpkg --configure trousers
  EOH
  only_if "dpkg -l trousers 2>&1 | grep -q 'no packages found'"
end

package "tpm-tools"
