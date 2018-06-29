#
# Cookbook Name:: bcpc
# Recipe:: mysql-backup
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

ruby_block "initial-mysql-backup-config" do
    block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -u root -e "GRANT SELECT,EVENT ON *.* TO '#{get_config('mysql-backup-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-backup-password')}';"
            mysql -u root -e "FLUSH PRIVILEGES;"
        ]
    end
    only_if {
      %x[MYSQL_PWD=#{get_config('mysql-root-password')} mysql -N --batch -uroot -e 'SELECT count(user) from mysql.user where user=\"#{get_config('mysql-backup-user')}\";'].to_i < 1
    }
end

# needed to disable/enable slow query logging
ruby_block "give-mysql-backup-user-super-privileges" do
    block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -u root -e "GRANT SUPER ON *.* TO '#{get_config('mysql-backup-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-backup-password')}';"
            mysql -u root -e "FLUSH PRIVILEGES;"
        ]
    end
    only_if {
      %x[MYSQL_PWD=#{get_config('mysql-root-password')} mysql -N --batch -uroot -e 'SELECT count(user) from mysql.user where user=\"#{get_config('mysql-backup-user')}\" AND super_priv = "Y";'].to_i < 1
    }
end
