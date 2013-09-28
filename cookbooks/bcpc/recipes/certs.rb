#
# Cookbook Name:: bcpc
# Recipe:: certs
#
# Copyright 2013, Bloomberg L.P.
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

template "/tmp/openssl.cnf" do
    source "openssl.cnf.erb"
    owner "root"
    group "root"
    mode 00644
end

ruby_block "initialize-ssh-keys" do
    block do
        make_config('ssh-private-key', %x[printf 'y\n' | ssh-keygen -t rsa -N '' -q -f /dev/stdout | sed -e '1,1d' -e 's/.*-----BEGIN/-----BEGIN/'])
        make_config('ssh-public-key', %x[echo "#{get_config('ssh-private-key')}" | ssh-keygen -y -f /dev/stdin])
        if get_config('ssl-certificate').nil? then
            temp = %x[openssl req -config /tmp/openssl.cnf -extensions v3_req -new -x509 -passout pass:temp_passwd -newkey rsa:4096 -out /dev/stdout -keyout /dev/stdout -days 1095 -subj "/C=#{node[:bcpc][:country]}/ST=#{node[:bcpc][:state]}/L=#{node[:bcpc][:organization]}/O=#{node[:bcpc][:company]}/OU=#{node[:bcpc][:region_name]}/CN=#{node[:bcpc][:domain_name]}/emailAddress=#{node[:bcpc][:admin_email]}"]
            make_config('ssl-private-key', %x[echo "#{temp}" | openssl rsa -passin pass:temp_passwd -out /dev/stdout])
            make_config('ssl-certificate', %x[echo "#{temp}" | openssl x509])
        end
    end
end

directory "/root/.ssh" do
    owner "root"
    group "root"
    mode 00700
end

template "/root/.ssh/authorized_keys" do
    source "authorized_keys.erb"
    owner "root"
    group "root"
    mode 00644
end

template "/root/.ssh/id_rsa" do
    source "id_rsa.erb"
    owner "root"
    group "root"
    mode 00600
end

template "/etc/ssl/certs/ssl-bcpc.pem" do
    source "ssl-bcpc.pem.erb"
    owner "root"
    group "root"
    mode 00644
end

directory "/etc/ssl/private" do
    owner "root"
    group "root"
    mode 00700
end

template "/etc/ssl/private/ssl-bcpc.key" do
    source "ssl-bcpc.key.erb"
    owner "root"
    group "root"
    mode 00600
end

