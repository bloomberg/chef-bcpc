#
# Cookbook Name:: bcpc
# Recipe:: backup-cluster
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

# This recipe configures the backup script to run on the bootstrap node.
# It must be paired with the bcpc::mysql-backup recipe, which configures
# MySQL on the head node with the database user set up here (otherwise
# the portion of the backup that tries to back up the database will fail).

# this will install from Ubuntu upstream rather than Percona, so
# it's 5.5 client instead of 5.6, but it works fine for the backup
package 'percona-xtradb-cluster-client'

# this user will be used for backing up both the main and monitoring MySQL
# clusters (if a monitoring cluster is present)
ruby_block 'create-mysql-backup-user' do
  block do
    make_config('mysql-backup-user', 'mysql_backup')
    make_config('mysql-backup-password', secure_password)
  end
end

directory '/root/.chef' do
  mode  00700
  owner 'root'
  group 'root'
end

cookbook_file '/root/.chef/knife.rb' do
  source 'mysql-backup.knife.rb'
  mode   00600
  owner  'root'
  group  'root'
end

backup_script = '/usr/local/bin/bcpc_backup.sh'
backup_dest = '/var/backups/bcpc'

template backup_script do
  source 'bcpc_backup.sh.erb'
  mode   00755
  owner  'root'
  group  'root'
  variables(
    lazy {
      {
        :monitoring_servers => search_nodes('recipe', 'mysql-monitoring')
      }
    }
  )
end

directory backup_dest do
  mode  00700
  owner 'root'
  group 'root'
end

template '/root/.my.main.cnf' do
  source 'mysql-backup.my.cnf.erb'
  mode   00600
  owner  'root'
  group  'root'
  variables(
    lazy {
      {
        :host         => node['bcpc']['management']['vip'],
        :port         => node['bcpc']['ports']['mysql'],
        :user_key     => 'mysql-backup-user',
        :password_key => 'mysql-backup-password'
      }
    }
  )
end

template '/root/.my.monitoring.cnf' do
  source 'mysql-backup.my.cnf.erb'
  mode   00600
  owner  'root'
  group  'root'
  variables(
    lazy {
      {
        :host         => node['bcpc']['monitoring']['vip'],
        :port         => 3306,
        :user_key     => 'mysql-backup-user',
        :password_key => 'mysql-backup-password'
      }
    }
  )
  not_if {
    node['bcpc']['monitoring']['vip'].nil?
  }
end

cron 'backup-bcpc-daily' do
  home    '/root'
  user    'root'
  minute  '0'
  hour    '0'
  command "#{backup_script} #{backup_dest} daily"
end

cron 'backup-bcpc-weekly' do
  home    '/root'
  user    'root'
  minute  '5'
  hour    '0'
  weekday '1'
  command "#{backup_script} #{backup_dest} weekly"
end

cron 'backup-bcpc-monthly' do
  home    '/root'
  user    'root'
  minute  '10'
  hour    '0'
  day     '1'
  command "#{backup_script} #{backup_dest} monthly"
end
