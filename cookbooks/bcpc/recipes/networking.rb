#
# Cookbook Name:: bcpc
# Recipe:: networking
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
include_recipe "bcpc::certs"

template "/etc/hosts" do
    source "hosts.erb"
    mode 00644
    variables( :servers => get_all_nodes )
end

template "/etc/ssh/sshd_config" do
    source "sshd_config.erb"
    mode 00644
    notifies :restart, "service[ssh]", :immediately
end

service "ssh" do
    action [ :enable, :start ]
end

service "cron" do
    action [ :enable, :start ]
end

# Core networking package
package "vlan"

# Useful system tools
package "fio"
package "bc"
package "htop"
package "sysstat"

# Remove spurious logging failures from this package
package "powernap" do
    action :remove
end

bash "enable-ip-forwarding" do
    user "root"
    code <<-EOH
        echo "1" > /proc/sys/net/ipv4/ip_forward
        sed --in-place '/^net.ipv4.ip_forward/d' /etc/sysctl.conf
        echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    EOH
    not_if "grep -e '^net.ipv4.ip_forward=1' /etc/sysctl.conf"
end

bash "enable-nonlocal-bind" do
    user "root"
    code <<-EOH
        echo "1" > /proc/sys/net/ipv4/ip_nonlocal_bind
        sed --in-place '/^net.ipv4.ip_nonlocal_bind/d' /etc/sysctl.conf
        echo 'net.ipv4.ip_nonlocal_bind=1' >> /etc/sysctl.conf
    EOH
    not_if "grep -e '^net.ipv4.ip_nonlocal_bind=1' /etc/sysctl.conf"
end

bash "set-tcp-keepalive-timeout" do
    user "root"
    code <<-EOH
        echo "1" > /proc/sys/net/ipv4/tcp_keepalive_time
        sed --in-place '/^net.ipv4.tcp_keepalive_time/d' /etc/sysctl.conf
        echo 'net.ipv4.tcp_keepalive_time=1800' >> /etc/sysctl.conf
    EOH
    not_if "grep -e '^net.ipv4.tcp_keepalive_time=1800' /etc/sysctl.conf"
end

bash "enable-mellanox" do
    user "root"
    code <<-EOH
                if [ -z "`lsmod | grep mlx4_en`" ]; then
                   modprobe mlx4_en
                fi
                if [ -z "`grep mlx4_en /etc/modules`" ]; then
                   echo "mlx4_en" >> /etc/modules
                fi
    EOH
    only_if "lspci | grep Mellanox"
end

bash "enable-8021q" do
    user "root"
    code <<-EOH
        modprobe 8021q
        sed --in-place '/^8021q/d' /etc/modules
        echo '8021q' >> /etc/modules
    EOH
    not_if "grep -e '^8021q' /etc/modules"
end

bash "interface-mgmt-make-static-if-dhcp" do
    user "root"
    code <<-EOH
        sed --in-place '/\\(.*#{node[:bcpc][:management][:interface]}.*\\)/d' /etc/network/interfaces
        echo >> /etc/network/interfaces
        echo "auto #{node[:bcpc][:management][:interface]}" >> /etc/network/interfaces
        echo "iface #{node[:bcpc][:management][:interface]} inet static" >> /etc/network/interfaces
        echo "  address #{node[:bcpc][:management][:ip]}" >> /etc/network/interfaces
        echo "  netmask #{node[:bcpc][:management][:netmask]}" >> /etc/network/interfaces
        echo "  gateway #{node[:bcpc][:management][:gateway]}" >> /etc/network/interfaces
        echo "  metric 100" >> /etc/network/interfaces
        ifup #{node[:bcpc][:management][:interface]}
    EOH
    only_if "cat /etc/network/interfaces | grep #{node[:bcpc][:management][:interface]} | grep dhcp"
end

bash "interface-storage" do
    user "root"
    code <<-EOH
        echo >> /etc/network/interfaces
        echo "auto #{node[:bcpc][:storage][:interface]}" >> /etc/network/interfaces
        echo "iface #{node[:bcpc][:storage][:interface]} inet static" >> /etc/network/interfaces
        echo "  address #{node[:bcpc][:storage][:ip]}" >> /etc/network/interfaces
        echo "  netmask #{node[:bcpc][:storage][:netmask]}" >> /etc/network/interfaces
        echo "  gateway #{node[:bcpc][:storage][:gateway]}" >> /etc/network/interfaces
        echo "  metric 300" >> /etc/network/interfaces
        ifup #{node[:bcpc][:storage][:interface]}
    EOH
    not_if "ifquery --list | grep #{node[:bcpc][:storage][:interface]}"
end

bash "interface-floating" do
    user "root"
    code <<-EOH
        echo >> /etc/network/interfaces
        echo "auto #{node[:bcpc][:floating][:interface]}" >> /etc/network/interfaces
        echo "iface #{node[:bcpc][:floating][:interface]} inet static" >> /etc/network/interfaces
        echo "  address #{node[:bcpc][:floating][:ip]}" >> /etc/network/interfaces
        echo "  netmask #{node[:bcpc][:floating][:netmask]}" >> /etc/network/interfaces
        echo "  gateway #{node[:bcpc][:floating][:gateway]}" >> /etc/network/interfaces
        echo "  dns-nameservers #{node[:bcpc][:management][:vip]} #{(n=node[:bcpc][:dns_servers].dup; n.push n.shift).join(' ')}" >> /etc/network/interfaces
        echo "  dns-search #{node[:bcpc][:domain_name]}" >> /etc/network/interfaces
        echo "  metric 200" >> /etc/network/interfaces
        ifup #{node[:bcpc][:floating][:interface]}
        resolvconf -d #{node[:bcpc][:management][:interface]}.dhclient
    EOH
    not_if "ifquery --list | grep #{node[:bcpc][:floating][:interface]}"
end

bash "routing-management" do
    user "root"
    code "echo '1 mgmt' >> /etc/iproute2/rt_tables"
    not_if "grep -e '^1 mgmt' /etc/iproute2/rt_tables"
end

bash "routing-storage" do
    user "root"
    code "echo '2 storage' >> /etc/iproute2/rt_tables"
    not_if "grep -e '^2 storage' /etc/iproute2/rt_tables"
end

template "/etc/network/if-up.d/bcpc-routing" do
    mode 00775
    source "bcpc-routing.erb"
    notifies :run, "execute[run-routing-script-once]", :immediately
end

execute "run-routing-script-once" do
    action :nothing
    command "/etc/network/if-up.d/bcpc-routing"
end

bash "disable-noninteractive-pam-logging" do
    user "root"
    code "sed --in-place 's/^\\(session\\s*required\\s*pam_unix.so\\)/#\\1/' /etc/pam.d/common-session-noninteractive"
    only_if "grep -e '^session\\s*required\\s*pam_unix.so' /etc/pam.d/common-session-noninteractive"
end

apt_repository "ceph-fcgi" do
    uri node['bcpc']['repos']['ceph-fcgi']
    distribution node['lsb']['codename']
    components ["main"]
    key "ceph-autobuild2.key"
end

apt_repository "ceph-apache" do
    uri node['bcpc']['repos']['ceph-apache']
    distribution node['lsb']['codename']
    components ["main"]
    key "ceph-autobuild2.key"
end

package "apache2" do
   action :upgrade
   version "2.2.22-1ubuntu1-inktank1"
end

package "libapache2-mod-fastcgi" do
   action :upgrade
   version "2.4.7~0910052141-1-inktank2"
end


directory "/etc/apache2/vhost-root.d" do
  owner "root"
  group "root"
  mode 00755
  action :create
end

directory "/etc/apache2/vhost-ssl-root.d" do
  owner "root"
  group "root"
  mode 00755
  action :create
end

template "/etc/apache2/vhost-root.d/000-default.conf" do
    source "apache-vhost-root-000-default.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end

template "/etc/apache2/vhost-ssl-root.d/000-default.conf" do
    source "apache-vhost-ssl-root-000-default.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end

template "/etc/apache2/sites-enabled/000-default" do
    source "apache-000-default.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end

%w{proxy_http rewrite ssl}.each do |mod|
    bash "apache-enable-#{mod}" do
        user "root"
        code <<-EOH
            a2enmod #{mod}
        EOH
        not_if "test -r /etc/apache2/mods-enabled/#{mod}.load"
        notifies :restart, "service[apache2]", :delayed
    end
end

bash "set-apache-bind-address" do
    code <<-EOH
        sed -i "s/\\\(^[\\\t ]*Listen[\\\t ]*\\\)80[\\\t ]*$/\\\\1#{node[:bcpc][:management][:ip]}:80/g" /etc/apache2/ports.conf
        sed -i "s/\\\(^[\\\t ]*Listen[\\\t ]*\\\)443[\\\t ]*$/\\\\1#{node[:bcpc][:management][:ip]}:443/g" /etc/apache2/ports.conf
    EOH
    not_if "grep #{node[:bcpc][:management][:ip]} /etc/apache2/ports.conf"
    notifies :restart, "service[apache2]", :immediately
end

service "apache2" do
    action [ :enable, :start ]
end

template "/var/www/index.html" do
    source "index.html.erb"
    owner "root"
    group "root"
    mode 00644
end
