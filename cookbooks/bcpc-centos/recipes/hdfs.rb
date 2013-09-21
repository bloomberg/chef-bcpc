#
# Cookbook Name:: bcpc-centos
# Recipe:: hdfs
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

yum_package "parted" do
  action :install
end

yum_package "xfsprogs" do
  action :install
end

yum_package "xfsprogs-devel" do
  action :install
end

node['bcpc']['hdfs_disks'].each do |disk|
  execute "hdfs_disk-prepare-#{disk}" do
    command <<-EOH
    /sbin/parted -a optimal -s /dev/#{disk} mklabel gpt
    /sbin/parted -a optimal -s /dev/#{disk} mkpart primary xfs 1049kB 100%
    /sbin/parted -a optimal -s /dev/#{disk} set 1 lvm on
    /sbin/mkfs.xfs -f /dev/#{disk}1
    EOH
    not_if "/sbin/parted /dev/#{disk} print | grep xfs"
  end
end

node['bcpc']['hdfs_disks'].each_with_index do |disk, i|
  dir = "/var/lib/hadoop/fs/%02d" % (i + 1)
  directory dir do
    owner "root"
    group "root"
    mode 00755
    recursive true
    action :create
  end
end

node['bcpc']['hdfs_disks'].each_with_index do |disk, i|
  execute "hdfs-update-fstab-#{disk}" do
    dir = "/var/lib/hadoop/fs/%02d" % (i + 1)
    command <<-EOH
    echo "/dev/#{disk}1 #{dir} xfs defaults 0 0" >> /etc/fstab
    /bin/mount #{dir}
    EOH
    not_if "cat /etc/fstab | grep #{dir}"
  end
end
