#
# Cookbook Name:: bcpc-ceph
# Recipe:: write-client-admin-key
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

include_recipe 'bcpc-ceph'

bash "write-client-admin-key" do
    code <<-EOH
        ADMIN_KEY=`ceph --name mon. --keyring /etc/ceph/ceph.mon.keyring auth get-or-create-key client.admin`
        ceph-authtool "/etc/ceph/ceph.client.admin.keyring" \
            --create-keyring \
            --name=client.admin \
            --add-key="$ADMIN_KEY"
        chmod 644 /etc/ceph/ceph.client.admin.keyring
    EOH
    not_if "test -f /etc/ceph/ceph.client.admin.keyring && chmod 644 /etc/ceph/ceph.client.admin.keyring"
end
