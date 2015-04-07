#
# Cookbook Name:: bcpc
# Recipe:: contrail-head
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

include_recipe "bcpc::contrail-common"

ruby_block "initialize-contrail-config" do
    block do
        make_config('contrail-api-passwd', secure_password)
        make_config('contrail-schema-passwd', secure_password)
        make_config('contrail-svc-monitor-passwd', secure_password)
        make_config('contrail-control-passwd', secure_password)
        make_config('contrail-dns-passwd', secure_password)
        make_config('contrail-metadata-secret', secure_password)
    end
end

%w{ ifmap-server
    contrail-config
    contrail-config-openstack
    contrail-analytics
    contrail-control
    contrail-dns
    contrail-utils
    contrail-web-controller
}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

# Workaround hardcoded rndc key in contrail-dns 1.20
bash "fix-hardcoded-rndc-key" do
    user "root"
    code <<-EOH
        sed --in-place 's/secret123/xvysmOR8lnUQRBcunkC6vg==/' /etc/contrail/dns/rndc.conf
    EOH
end

# Workaround missing init scripts for contrail-named
template "/etc/init/contrail-named.conf" do
    source "upstart-contrail-named.conf.erb"
    owner "root"
    group "root"
    mode 00644
end
link "/etc/init.d/contrail-named" do
    to "/lib/init/upstart-job"
end

# Workaround for disabled SSLv3 in java (only needed for contrail 1.20, fixed upstream)
bash "fix-java-ssl" do
    user "root"
    code <<-EOH
        sed --in-place 's/^jdk.tls.disabledAlgorithms=SSLv3/#jdk.tls.disabledAlgorithms=SSLv3/' /etc/java-6-openjdk/security/java.security
    EOH
    only_if "egrep '^jdk.tls.disabledAlgorithms=SSLv3' /etc/java-6-openjdk/security/java.security"
end

# Needed to get around CA cert not being settable in all Contrail services
bash "add-cert-to-certifi" do
    user "root"
    code "cat /etc/ssl/certs/ssl-bcpc.pem >> /usr/lib/python2.7/dist-packages/certifi/cacert.pem"
    not_if "grep \"Generated by Chef\" /usr/lib/python2.7/dist-packages/certifi/cacert.pem"
end

template "/etc/ifmap-server/ifmap.properties" do
    source "ifmap.properties.erb"
    mode 00644
    notifies :restart, "service[ifmap-server]", :delayed
end

template "/etc/ifmap-server/basicauthusers.properties" do
    source "ifmap-basicauthusers.properties.erb"
    mode 00644
    variables(:servers => get_head_nodes)
    notifies :restart, "service[ifmap-server]", :immediately
end

template "/etc/contrail/vnc_api_lib.ini" do
    source "contrail-vnc_api_lib.ini.erb"
    owner "contrail"
    group "contrail"
    # The neutron user must be able to read this
    mode 00644
    notifies :restart, "service[contrail-api]", :delayed
end

template "/etc/contrail/svc-monitor.conf" do
    source "contrail-svc-monitor.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables(:servers => get_head_nodes)
    notifies :restart, "service[contrail-svc-monitor]", :delayed
end

%w{ contrail-discovery
    contrail-control
    contrail-api
    contrail-schema
    contrail-analytics-api
    contrail-collector
    contrail-query-engine
}.each do |pkg|
    template "/etc/contrail/#{pkg}.conf" do
        source "#{pkg}.conf.erb"
        owner "contrail"
        group "contrail"
        mode 00640
        variables(:servers => get_head_nodes)
        notifies :restart, "service[#{pkg}]", :immediately
    end
end

template "/etc/contrail/dns.conf" do
    source "contrail-dns.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    notifies :restart, "service[contrail-dns]", :immediately
    notifies :restart, "service[contrail-named]", :immediately
end

template "/var/lib/contrail-webui/contrail-web-core/keys/cs-cert.pem" do
    source "ssl-bcpc.pem.erb"
    owner "contrail"
    group "contrail"
    mode 00644
    notifies :restart, "service[contrail-webui-jobserver]", :delayed
    notifies :restart, "service[contrail-webui-webserver]", :delayed
end

template "/var/lib/contrail-webui/contrail-web-core/keys/cs-key.pem" do
    source "ssl-bcpc.key.erb"
    owner "contrail"
    group "contrail"
    mode 00600
    notifies :restart, "service[contrail-webui-jobserver]", :delayed
    notifies :restart, "service[contrail-webui-webserver]", :delayed
end

template "/etc/contrail/config.global.js" do
    source "contrail-config.global.js.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables(:servers => get_head_nodes)
    notifies :restart, "service[contrail-webui-jobserver]", :immediately
    notifies :restart, "service[contrail-webui-webserver]", :immediately
end

%w{ ifmap-server
    contrail-discovery
    contrail-api
    contrail-schema
    contrail-svc-monitor
    contrail-analytics-api
    contrail-collector
    contrail-query-engine
    contrail-control
    contrail-dns
    contrail-named
    contrail-webui-jobserver
    contrail-webui-webserver
}.each do |svc|
    service svc do
        action [:enable, :start]
    end
end

bash "provision-linklocal-metadata" do
    user "root"
    code <<-EOH
        contrail-provision-linklocal \
            --conf_file /etc/contrail/contrail-schema.conf \
            --linklocal_service_name metadata \
            --linklocal_service_ip 169.254.169.254 \
            --linklocal_service_port 80 \
            --ipfabric_service_ip 127.0.0.1 \
            --ipfabric_service_port 8775
    EOH
end

bash "provision-global-asn" do
    user "root"
    code <<-EOH
        contrail-provision-control \
            --conf_file /etc/contrail/contrail-schema.conf \
            --router_asn #{node['bcpc']['contrail_asn']}
    EOH
end

bash "provision-control-node" do
    user "root"
    code <<-EOH
        contrail-provision-control \
            --conf_file /etc/contrail/contrail-schema.conf \
            --host_name #{node['hostname']} \
            --host_ip #{node['bcpc']['management']['ip']} \
            --oper add
    EOH
end

bash "provision-encap" do
    user "root"
    code <<-EOH
        contrail-provision-encap \
            --conf_file /etc/contrail/contrail-schema.conf \
            --encap_priority MPLSoUDP,MPLSoGRE,VXLAN \
            --oper add
    EOH
end

get_all_nodes.each do |server|
    bash "provision-vrouter-#{server['hostname']}" do
        user "root"
        code <<-EOH
            contrail-provision-vrouter \
                --conf_file /etc/contrail/contrail-schema.conf \
                --host_name #{server['hostname']} \
                --host_ip #{server['bcpc']['floating']['ip']}
        EOH
    end
end

# Neutron needs to be setup before we can setup the Floating IPs
include_recipe "bcpc::neutron"

bash "create-public-network" do
    user "root"
    code <<-EOH
        . /root/adminrc
        neutron net-create --shared --router:external #{node['bcpc']['region_name']}
        neutron subnet-create --name #{node['bcpc']['region_name']}-subnet1 #{node['bcpc']['region_name']} #{node['bcpc']['floating']['available_subnet']}
    EOH
    not_if ". /root/adminrc; neutron net-list | grep #{node['bcpc']['region_name']}"
end

include_recipe "bcpc::contrail-work"

if node['bcpc']['enabled']['contrail_dev_nat'] then

    template "/etc/network/interfaces.d/iface-vgw" do
        source "network.vgw.erb"
        owner "root"
        group "root"
        mode 00644
    end

    bash "vgw-up" do
        user "root"
        code "ifup vgw"
        not_if "ip link show up | grep vgw"
    end

    bash "route-and-nat-for-vgw" do
        user "root"
        code <<-EOH
            route add -net #{node['bcpc']['floating']['available_subnet']} dev vgw
            iptables -t nat -A POSTROUTING -o vhost0 -j MASQUERADE
            iptables -A FORWARD -i vhost0 -o vgw -m state --state RELATED,ESTABLISHED -j ACCEPT
            iptables -A FORWARD -i vgw -o vhost0 -j ACCEPT
        EOH
        not_if "ip route show | grep #{node['bcpc']['floating']['available_subnet']}"
    end

end
