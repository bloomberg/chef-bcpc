#
# Cookbook Name:: bcpc-proxysql
# Provider:: adminsql
#
# Copyright 2016, Bloomberg Finance L.P.
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
require 'open3'

def whyrun_supported?
  true
end

use_inline_resources

action :execute do
  envvars = {
    'MYSQL_HOST' => @new_resource.admin_hostname,
    'MYSQL_TCP_PORT' => @new_resource.admin_port,
    'MYSQL_PWD' => get_config('proxysql-admin-password')
  }
  dbuser = get_config('proxysql-admin-user')
  mysql_cmd = "mysql -N -s -u #{dbuser} -D admin -e \"#{@new_resource.query}\""
  Open3.popen2e(envvars, mysql_cmd) { |_stdin, stdouterr, p|
    raise "Failed (#{p.value}): #{query} - #{stdouterr.read}" if p.value != 0
  }
end
