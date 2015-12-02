#
# Cookbook Name:: bcpc-foundation
# Recipe:: certs
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

template "/tmp/openssl.cnf" do
    source "openssl.cnf.erb"
    owner "root"
    group "root"
    mode 00644
end

ruby_block "read-ssl-certificate" do
  block do
    begin
      require 'openssl'
      if !node['bcpc']['ssl_certificate'].nil? and !node['bcpc']['ssl_private_key'].nil?
        ssl_path = Chef::Config['file_cache_path'] + "/cookbooks/bcpc/files/default/"
        cert = OpenSSL::X509::Certificate.new File.read(ssl_path + node['bcpc']['ssl_certificate'])
        key  = OpenSSL::PKey::RSA.new File.read(ssl_path + node['bcpc']['ssl_private_key'])
        make_config('ssl-private-key', key.to_pem)
        make_config('ssl-certificate', cert.to_pem)
        if !node['bcpc']['ssl_intermediate_certificate'].nil?
            intermediate_cert = OpenSSL::X509::Certificate.new File.read(ssl_path + node['bcpc']['ssl_intermediate_certificate'])
            make_config('ssl-intermediate-certificate', intermediate_cert.to_pem)
        end
      else
        Chef::Log.warn("SSL certificate and/or key are not specified, will generate self-signed certificate")
      end
      if !node['bcpc']['s3_ssl_certificate'].nil? and !node['bcpc']['s3_ssl_private_key'].nil?
        s3_ssl_path = Chef::Config['file_cache_path'] + "/cookbooks/bcpc/files/default/"
        s3_cert = OpenSSL::X509::Certificate.new File.read(s3_ssl_path + node['bcpc']['s3_ssl_certificate'])
        s3_key  = OpenSSL::PKey::RSA.new File.read(s3_ssl_path + node['bcpc']['s3_ssl_private_key'])
        make_config('s3-ssl-private-key', s3_key.to_pem)
        make_config('s3-ssl-certificate', s3_cert.to_pem)
        if !node['bcpc']['s3_ssl_intermediate_certificate'].nil?
            s3_intermediate_cert = OpenSSL::X509::Certificate.new File.read(s3_ssl_path + node['bcpc']['s3_ssl_intermediate_certificate'])
            make_config('s3-ssl-intermediate-certificate', s3_intermediate_cert.to_pem)
        end
      else
        Chef::Log.warn("S3 SSL certificate and/or key are not specified, will use self-signed certificate")
      end
    rescue Exception => e
      raise("Unable to process specified SSL certificate: " + e.message)
    end
  end
end

ruby_block "initialize-ssh-keys" do
    block do
        require 'openssl'
        require 'net/ssh'
        key = OpenSSL::PKey::RSA.new 2048;
        pubkey = "#{key.ssh_type} #{[key.to_blob].pack('m0')}"
        make_config('ssh-private-key', key.to_pem.strip)
        make_config('ssh-public-key', pubkey.strip)
        begin
            get_config('ssl-certificate')
        rescue
            temp = %x[openssl req -config /tmp/openssl.cnf -extensions v3_req -new -x509 -passout pass:temp_passwd -newkey rsa:4096 -out /dev/stdout -keyout /dev/stdout -days 1095 -subj "/C=#{node['bcpc']['country']}/ST=#{node['bcpc']['state']}/L=#{node['bcpc']['location']}/O=#{node['bcpc']['organization']}/OU=#{node['bcpc']['region_name']}/CN=openstack.#{node['bcpc']['cluster_domain']}/emailAddress=#{node['bcpc']['admin_email']}"]
            make_config_from_cmd('ssl-private-key', "echo \"#{temp}\" | openssl rsa -passin pass:temp_passwd -out /dev/stdout")
            make_config_from_cmd('ssl-certificate', "echo \"#{temp}\" | openssl x509")
        end
        begin
            get_config('s3-ssl-certificate')
        rescue
            make_config('s3-ssl-private-key', get_config('ssl-private-key'))
            make_config('s3-ssl-certificate', get_config('ssl-certificate'))
        end
    end
end

ruby_block "set-ssh-host-key-reference" do
  block do
    if node['bcpc']['ssh_host_key'].nil?
      cmd = Mixlib::ShellOut.new("ssh-keyscan #{node['bcpc']['management']['ip']} #{node['hostname']}").run_command
      node.set['bcpc']['ssh_host_key'] = cmd.stdout
      node.save rescue nil
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
    mode 00640
end

template "/root/.ssh/id_rsa" do
    source "id_rsa.erb"
    owner "root"
    group "root"
    mode 00600
end

template "/root/.ssh/known_hosts" do
    source "known_hosts.erb"
    owner "root"
    group "root"
    mode 00644
    variables(
      lazy {
        {:servers => get_all_nodes}
      }
    )
end

template "/etc/ssl/certs/ssl-bcpc.pem" do
    source "ssl-bcpc.pem.erb"
    owner "root"
    group "root"
    mode 00644
end

template "/usr/local/share/ca-certificates/bcpc-intermediate.crt" do
    source "bcpc-intermediate.pem.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :run, "execute[reload-ca-certificates]", :immediately
    only_if { node['bcpc']['ssl_intermediate_certificate'] }
end

template "/usr/local/share/ca-certificates/ssl-bcpc.crt" do
    source "ssl-bcpc.pem.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :run, "execute[reload-ca-certificates]", :immediately
end

execute "reload-ca-certificates" do
    action :nothing
    command "update-ca-certificates"
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
