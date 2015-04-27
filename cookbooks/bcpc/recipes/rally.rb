#
# Cookbook Name:: bcpc
# Recipe:: rally
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

# This recipe simply installs rally on the given node (bootstrap by default). The rally-setup.rb will set rally
# up to be able to be ran.

# Note: Added package default-jre so that java is already installed during the bootstrapping for JMeter

rally_user = node['bcpc']['rally']['user']

%w{
    wget
    build-essential
    libssl-dev
    libffi-dev
    python-dev
    libpq-dev
    libxml2-dev
    libxslt1-dev
    default-jre
}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

cookbook_file "/tmp/rally-pip.tar.gz" do
    source "bins/rally-pip.tar.gz"
    owner "root"
    mode 00444
end

cookbook_file "/tmp/rally-bin.tar.gz" do
    source "bins/rally-bin.tar.gz"
    owner "root"
    mode 00444
end

cookbook_file "/tmp/rally.tar.gz" do
    source "bins/rally.tar.gz"
    owner "root"
    mode 00444
end

cookbook_file "/tmp/python-pip_6.1.1_all.deb" do
    source "bins/python-pip_6.1.1_all.deb"
    owner "root"
    mode 00444
end

dpkg_package "python-pip" do
    source "/tmp/python-pip_6.1.1_all.deb"
    action :install
end

bash "rally-pip-bin" do
    user "root"
    code <<-EOH
        tar xvf /tmp/rally-pip.tar.gz -C /usr/local/lib/python2.7/dist-packages .
        tar xvf /tmp/rally-bin.tar.gz -C /usr/local/bin .
        #easy_install -H None -f /usr/local/lib/python2.7/dist-packages rally
    EOH
    not_if "test -d /usr/local/lib/python2.7/dist-packages/rally-0.0.3-py2.7.egg"
end

# Make sure these directories are present
# If this directory changes then make sure to change rally-setup.rb to reflect the change
directory "/var/lib/rally/database" do
  owner 'root'
  group 'root'
  mode '0777'
  action :create
  recursive true
end

directory "/opt/rally" do
  owner "#{rally_user}"
  group "#{rally_user}"
  mode '0755'
  action :create
end

directory "/etc/rally" do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# Rally config file does not have any variables at the moment but is a template anyway.
template "/etc/rally/rally.conf" do
    source "rally.conf.erb"
    owner "root"
    group "root"
    mode 0664
end

# Extract the rally source tree so that the tests are available
# If the 'mv' command fails then no worries. The returns [0, 1, 2] will allows the recipe to continue
bash "install-rally-source" do
    code <<-EOH
        tar xvf /tmp/rally.tar.gz -C /opt/rally
        mv /opt/rally/install_rally.sh /opt/rally/install_rally.sh.do_not_run
        chown -R #{rally_user}:#{rally_user} /opt/rally
    EOH
    not_if "test -f /opt/rally/install_rally.sh.do_not_run"
    returns [0, 1, 2]
end

# Wanted to also setup rally here but 'rally deployment create' also verifies the endpoints which have not been
# setup at this stage.
#include_recipe "bcpc::rally-setup"
