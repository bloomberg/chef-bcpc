#
# Cookbook Name:: bcpc-proxysql
# Resource:: adminsql
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

actions :execute
default_action :execute

attribute :admin_hostname,
          :kind_of => String,
          :default => \
          node['bcpc-proxysql']['admin']['config']['proxysql_hostname']
attribute :admin_port,
          :kind_of => String,
          :default => \
          node['bcpc-proxysql']['admin']['config']['proxysql_port'].to_s
# SQL query to execute
attribute :query, :name_attribute => true, :kind_of => String, :required => true
