#
# Cookbook Name:: bcpc
# Recipe:: 389ds
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

include_recipe "bcpc::default"

ruby_block "initialize-389ds-config" do
    block do
        make_config('389ds-admin-user', "admin")
        make_config('389ds-admin-password', secure_password)
        make_config('389ds-rootdn-user', "cn=Directory Manager")
        make_config('389ds-rootdn-password', secure_password)
        make_config('389ds-replication-user', "cn=Replication Manager")
        make_config('389ds-replication-password', secure_password)
    end
end

%w{389-ds ldap-utils}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

template "/tmp/389ds-install.inf" do
    source "389ds-install.inf.erb"
    owner "root"
    group "root"
    mode 00600
end

bash "setup-389ds-server" do
    user "root"
    code <<-EOH
        setup-ds-admin --file=/tmp/389ds-install.inf -k -s
        service dirsrv stop
        service dirsrv-admin stop
        sed --in-place 's/^ServerLimit.*/ServerLimit 64/' /etc/dirsrv/admin-serv/httpd.conf
        sed --in-place '/^MinSpareThreads/d' /etc/dirsrv/admin-serv/httpd.conf
        sed --in-place '/^MaxSpareThreads/d' /etc/dirsrv/admin-serv/httpd.conf
        sed --in-place '/^ThreadsPerChild/d' /etc/dirsrv/admin-serv/httpd.conf
        sed --in-place 's/^nsslapd-port.*/nsslapd-listenhost: #{node['bcpc']['management']['ip']}\\nnsslapd-port: 389/' /etc/dirsrv/slapd-#{node['hostname']}/dse.ldif
        echo "dn: cn=Replication Manager,cn=config" >> /etc/dirsrv/slapd-#{node['hostname']}/dse.ldif
        echo "objectClass: inetorgperson" >> /etc/dirsrv/slapd-#{node['hostname']}/dse.ldif
        echo "objectClass: person" >> /etc/dirsrv/slapd-#{node['hostname']}/dse.ldif
        echo "objectClass: top" >> /etc/dirsrv/slapd-#{node['hostname']}/dse.ldif
        echo "cn: Replication Manager" >> /etc/dirsrv/slapd-#{node['hostname']}/dse.ldif
        echo "sn: RM" >> /etc/dirsrv/slapd-#{node['hostname']}/dse.ldif
        echo "userPassword: #{get_config('389ds-replication-password')}" >> /etc/dirsrv/slapd-#{node['hostname']}/dse.ldif
        echo "passwordExpirationTime: 20380119031407Z" >> /etc/dirsrv/slapd-#{node['hostname']}/dse.ldif
        echo "nsIdleTimeout: 0" >> /etc/dirsrv/slapd-#{node['hostname']}/dse.ldif
        service dirsrv start
        service dirsrv-admin start
    EOH
    not_if "test -d /etc/dirsrv/slapd-#{node['hostname']}"
    notifies :create, "ruby_block[ldap-requires-initialization]", :immediately
    notifies :create, "ruby_block[disable-anonymous-bind]", :immediately
end

ruby_block "ldap-requires-initialization" do
    action :nothing
    block do
        node.set['bcpc']['ldap_initialized'] = false
        node.save rescue nil
    end
end

ruby_block "disable-anonymous-bind" do
    action :nothing
    block do
        %x[ ldapmodify -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" << EOH
dn: cn=config
changetype: modify
replace: nsslapd-allow-anonymous-access
nsslapd-allow-anonymous-access: off

        ]
    end
end

# Delete some of the default groups that won't be used
['Accounting Managers', 'HR Managers', 'PD Managers', 'QA Managers'].each do |cn|
    ruby_block "create-cn-for-#{cn}" do
        block do
            if system "ldapsearch -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" -b \"#{node['bcpc']['domain_name'].split('.').collect { |x| 'dc='+x }.join(',')}\" \"(cn=#{cn})\" | grep ^dn: > /dev/null 2>&1" then
                %x[ ldapmodify -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" << EOH
dn: cn=#{cn},ou=Groups,#{node['bcpc']['domain_name'].split('.').collect { |x| 'dc='+x }.join(',')}
changetype: delete

                ]
            end
        end
    end
end

# Create an OU for tenants and for roles (we will use the existing ou=People)
%w{ Tenants Roles }.each do |ou|
    ruby_block "create-ou-for-#{ou}" do
        block do
            if not system "ldapsearch -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" -b \"#{node['bcpc']['domain_name'].split('.').collect { |x| 'dc='+x }.join(',')}\" \"(ou=#{ou})\" | grep ^dn: > /dev/null 2>&1" then
                %x[ ldapmodify -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" << EOH
dn: ou=#{ou},#{node['bcpc']['domain_name'].split('.').collect { |x| 'dc='+x }.join(',')}
changetype: add
objectClass: top
objectClass: organizationalunit
ou: #{ou}

                ]
            end
        end
    end
end

# Create a CN to hold the list of enabled users and tenants
%w{ Users Tenants }.each do |cn|
    ruby_block "create-cn-for-#{cn}" do
        block do
            if not system "ldapsearch -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" -b \"#{node['bcpc']['domain_name'].split('.').collect { |x| 'dc='+x }.join(',')}\" \"(cn=OpenStack #{cn})\" | grep ^dn: > /dev/null 2>&1" then
                %x[ ldapmodify -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" << EOH
dn: cn=OpenStack #{cn},ou=Groups,#{node['bcpc']['domain_name'].split('.').collect { |x| 'dc='+x }.join(',')}
changetype: add
objectclass: top
objectclass: groupOfNames
ou: groups

                ]
            end
        end
    end
end

# Create a changelog so that we can setup replication
ruby_block "create-ldap-changelog" do
    block do
        if not system "ldapsearch -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" -b cn=config \"(cn=changelog5)\" | grep -v filter | grep changelog5 > /dev/null 2>&1" then
            %x[ ldapmodify -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" << EOH
dn: cn=changelog5,cn=config
changetype: add
objectclass: top
objectclass: extensibleObject
cn: changelog5
nsslapd-changelogdir: /var/lib/dirsrv/slapd-#{node['hostname']}/changelogdb

            ]
        end
    end
end

# Create a replica object to hold our replication agreements
ruby_block "create-ldap-supplier-replica" do
    block do
        if not system "ldapsearch -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" -b cn=config \"(cn=replica)\" | grep -v filter | grep replica > /dev/null 2>&1" then
            domain = node['bcpc']['domain_name'].split('.').collect { |x| 'dc='+x }.join(',')
            %x[ ldapmodify -h #{node['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" << EOH
dn: cn=replica,cn="#{domain}",cn=mapping tree,cn=config
changetype: add
objectclass: top
objectclass: nsds5replica
objectclass: extensibleObject
cn: replica
nsds5replicaroot: #{domain}
nsds5replicaid: #{node['bcpc']['node_number']}
nsds5replicatype: 3
nsds5flags: 1
nsds5ReplicaPurgeDelay: 604800
nsds5ReplicaBindDN: #{get_config('389ds-replication-user')},cn=config

            ]
        end
    end
end

get_head_nodes.each do |server|
    ruby_block "setup-ldap-replication-from-#{server['hostname']}" do
        only_if { server['hostname'] != node['hostname'] }
        block do
            # Setup replication from the other head node to us
            if not system "ldapsearch -h #{server['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" -b cn=config \"(cn=To-#{node['hostname']})\" | grep -v filter | grep #{node['hostname']} > /dev/null 2>&1" then
                domain = node['bcpc']['domain_name'].split('.').collect { |x| 'dc='+x }.join(',')
                %x[ ldapmodify -h #{server['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" << EOH
dn: cn=To-#{node['hostname']},cn=replica,cn="#{domain}",cn=mapping tree,cn=config
changetype: add
objectclass: top
objectclass: nsds5replicationagreement
cn: To-#{node['hostname']}
nsds5replicahost: #{node['bcpc']['management']['ip']}
nsds5replicaport: 389
nsds5ReplicaBindDN: #{get_config('389ds-replication-user')},cn=config
nsds5replicabindmethod: SIMPLE
nsds5replicaroot: #{domain}
description: Agreement to sync from #{server['hostname']} to #{node['hostname']}
nsds5replicatedattributelist: (objectclass=*) $ EXCLUDE authorityRevocationList
nsds5replicacredentials: #{get_config('389ds-replication-password')}

                ]
                # Initialize this node once if it's brand new
                if not node['bcpc']['ldap_initialized'] then
                    %x[ ldapmodify -h #{server['bcpc']['management']['ip']} -p 389  -D \"#{get_config('389ds-rootdn-user')}\" -w \"#{get_config('389ds-rootdn-password')}\" << EOH
dn: cn=To-#{node['hostname']},cn=replica,cn="#{domain}",cn=mapping tree,cn=config
changetype: modify
add: nsds5BeginReplicaRefresh
nsds5BeginReplicaRefresh: start

                    ]
                    node.set['bcpc']['ldap_initialized'] = true
                    node.save rescue nil
                end
            end
        end
    end
end

%w{ dirsrv dirsrv-admin }.each do |svc|
    service svc do
        action [:enable, :start]
    end
end

package "phpldapadmin" do
    action :upgrade
end

template "/etc/phpldapadmin/config.php" do
    source "phpldapadmin-config.php.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end
