#
# Cookbook Name:: bcpc-proxysql
# Recipe:: logrotate
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

logrotate_app 'proxysql' do
  path ['/var/lib/proxysql/proxysql.log', '/var/lib/proxysql/check.log']
  frequency 'daily'
  create '600 proxysql proxysql'
  rotate 7
end
