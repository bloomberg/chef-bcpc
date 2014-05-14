#!/bin/bash

if [ X"$1" = X ]; then
    echo " ** one argument required (environment name)"
    exit -1
fi

if [ ! -f roles/$1.json ]; then
    echo " ** must create roles/$1.json first..."
    echo "    (try 'cp roles/Env-Example.json roles/$1.json' and editing)"
    exit -1
fi

if [ -f data_bags/configs/$1.json ]; then
    echo " ** file data_bags/configs/$1.json already exists"
    exit -1
fi

./make_secret.sh

erubis -c "context['environ']='$1'" <<EOH 2>/dev/null | knife solo data bag create configs $1 --json-file /dev/stdin --data-bag-path data_bags --secret-file secret_file
<%
require 'openssl'
require 'json'
require 'net/ssh'
require 'erubis'

JSON.create_id = nil
node = JSON.parse(IO.read("roles/#{@environ}.json"))['override_attributes']
node['bcpc']['region_name'] = @environ

require 'cookbooks/bcpc/libraries/utils.rb'

ssl_conf = Erubis::Eruby.new(IO.read("cookbooks/bcpc/templates/default/openssl.cnf.erb")).result(:node=>node)
File.open("/tmp/openssl.cnf", 'w') {|f| f.write(ssl_conf)}
%>
{
    "id": "<%="#{node['bcpc']['region_name']}"%>",
    "389ds-admin-password": "<%="#{secure_password}"%>",
    "389ds-admin-user": "admin",
    "389ds-replication-password": "<%="#{secure_password}"%>",
    "389ds-replication-user": "cn=Replication Manager",
    "389ds-rootdn-password": "<%="#{secure_password}"%>",
    "389ds-rootdn-user": "cn=Directory Manager",
    "ceilometer-secret": "<%="#{secure_password}"%>",
    "ceph-fs-uuid": "<%="#{%x[uuidgen].strip.downcase}"%>",
    "ceph-mon-key": "<%="#{ceph_keygen}"%>",
    "glance-cloudpipe-uuid": "<%="#{%x[uuidgen].strip.downcase}"%>",
    "graphite-secret-key": "<%="#{secure_password}"%>",
    "haproxy-stats-password": "<%="#{secure_password}"%>",
    "haproxy-stats-user": "haproxy",
    "horizon-secret-key": "<%="#{secure_password}"%>",
    "keepalived-password": "<%="#{secure_password}"%>",
    "keepalived-router-id": "<%="#{(rand * 1000).to_i%254/2*2+1}"%>",
    "keystone-admin-password": "<%="#{secure_password}"%>",
    "keystone-admin-token": "<%="#{secure_password}"%>",
    "keystone-admin-user": "admin",
    <% temp = %x[openssl req -new -x509 -passout pass:temp_passwd -newkey rsa:2048 -out /dev/stdout -keyout /dev/stdout -days 1095 -subj "/C=#{node['bcpc']['country']}/ST=#{node['bcpc']['state']}/L=#{node['bcpc']['location']}/O=#{node['bcpc']['organization']}/OU=#{node['bcpc']['region_name']}/CN=keystone.#{node['bcpc']['domain_name']}/emailAddress=#{node['bcpc']['admin_email']}"] %>
    "keystone-pki-certificate": "<%="#{%x[echo "#{temp}" | openssl x509].gsub(/\n/,'\n')}"%>",
    "keystone-pki-private-key": "<%="#{%x[echo "#{temp}" | openssl rsa -passin pass:temp_passwd -out /dev/stdout].gsub(/\n/,'\n')}"%>",
    "keystone-test-password": "<%="#{secure_password}"%>",
    "keystone-test-user": "tester",
    "libvirt-secret-uuid": "<%="#{%x[uuidgen].strip.downcase}"%>",
    "mysql-ceilometer-password": "<%="#{secure_password}"%>",
    "mysql-ceilometer-user": "ceilometer",
    "mysql-check-password": "<%="#{secure_password}"%>",
    "mysql-check-user": "check",
    "mysql-cinder-password": "<%="#{secure_password}"%>",
    "mysql-cinder-user": "cinder",
    "mysql-galera-password": "<%="#{secure_password}"%>",
    "mysql-galera-user": "sst",
    "mysql-glance-password": "<%="#{secure_password}"%>",
    "mysql-glance-user": "glance",
    "mysql-graphite-password": "<%="#{secure_password}"%>",
    "mysql-graphite-user": "graphite",
    "mysql-heat-password": "<%="#{secure_password}"%>",
    "mysql-heat-user": "heat",
    "mysql-horizon-password": "<%="#{secure_password}"%>",
    "mysql-horizon-user": "horizon",
    "mysql-keystone-password": "<%="#{secure_password}"%>",
    "mysql-keystone-user": "keystone",
    "mysql-nova-password": "<%="#{secure_password}"%>",
    "mysql-nova-user": "nova",
    "mysql-pdns-password": "<%="#{secure_password}"%>",
    "mysql-pdns-user": "pdns",
    "mysql-phpmyadmin-password": "<%="#{secure_password}"%>",
    "mysql-root-password": "<%="#{secure_password}"%>",
    "mysql-root-user": "root",
    "mysql-zabbix-password": "<%="#{secure_password}"%>",
    "mysql-zabbix-user": "zabbix",
    "rabbitmq-cookie": "<%="#{secure_password}"%>",
    "rabbitmq-password": "<%="#{secure_password}"%>",
    "rabbitmq-user": "guest",
    "radosgw-admin-access-key": "<%="#{secure_password_alphanum_upper}"%>",
    "radosgw-admin-secret-key": "<%="#{secure_password(40)}"%>",
    "radosgw-admin-user": "radosgw",
    "radosgw-test-access-key": "<%="#{secure_password_alphanum_upper}"%>",
    "radosgw-test-secret-key": "<%="#{secure_password(40)}"%>",
    "radosgw-test-user": "tester",
    <% key = OpenSSL::PKey::RSA.new 2048; pubkey = "#{key.ssh_type} #{[ key.to_blob ].pack('m0')}" %>
    "ssh-nova-private-key": "<%="#{key.to_pem.gsub(/\n/,'\n')}"%>",
    "ssh-nova-public-key": "<%="#{pubkey.gsub(/\n/,'')}"%>",
    <% key = OpenSSL::PKey::RSA.new 2048; pubkey = "#{key.ssh_type} #{[ key.to_blob ].pack('m0')}" %>
    "ssh-private-key": "<%="#{key.to_pem.gsub(/\n/,'\n')}"%>",
    "ssh-public-key": "<%="#{pubkey.gsub(/\n/,'')}"%>",
    <% temp = %x[openssl req -config /tmp/openssl.cnf -extensions v3_req -new -x509 -passout pass:temp_passwd -newkey rsa:4096 -out /dev/stdout -keyout /dev/stdout -days 1095 -subj "/C=#{node['bcpc']['country']}/ST=#{node['bcpc']['state']}/L=#{node['bcpc']['location']}/O=#{node['bcpc']['organization']}/OU=#{node['bcpc']['region_name']}/CN=#{node['bcpc']['domain_name']}/emailAddress=#{node['bcpc']['admin_email']}"] %>
    "ssl-certificate": "<%="#{%x[echo "#{temp}" | openssl x509].gsub(/\n/,'\n')}"%>",
    "ssl-private-key": "<%="#{%x[echo "#{temp}" | openssl rsa -passin pass:temp_passwd -out /dev/stdout].gsub(/\n/,'\n')}"%>",
    "zabbix-admin-password": "<%="#{secure_password}"%>",
    "zabbix-admin-user": "admin",
    "zabbix-guest-password": "<%="#{secure_password}"%>",
    "zabbix-guest-user": "guest"
}
EOH

cat data_bags/configs/$1.json | python -mjson.tool > data_bags/configs/$1.json.new
mv -f data_bags/configs/$1.json.new data_bags/configs/$1.json
echo " ** created data_bags/configs/$1.json"

if [ ! -f id_rsa ]; then
    touch id_rsa
    chmod 600 id_rsa
    erubis <<EOH 2>/dev/null >> id_rsa
<%
require 'json'
JSON.create_id = nil
bag = JSON.parse(%x[knife solo data bag show configs $1 --data-bag-path data_bags --secret-file secret_file -fjson])
%>
<%="#{bag['ssh-private-key']}"%>
EOH
    echo " ** created ./id_rsa with ssh key for BCPC nodes"
fi
