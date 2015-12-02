#
# Cookbook Name:: bcpc-zabbix
# Library:: default
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
require 'json'
require 'net/http'
require 'uri'

def zbx_api(auth, method, params)
  uri = URI.parse("http://#{node['bcpc']['management']['ip']}:7777/api_jsonrpc.php")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.request_uri, initheader = {'Content-Type' => 'application/json'})
  body = {
    :method  => method,
    :id      => 1,
    :jsonrpc => '2.0',
    :params  => params
  }
  body = body.merge({:auth => auth}) if method != 'user.login'
  request.body = body.to_json

  response = http.request(request)
  raise "Method #{method} failed: #{response.body}" unless response.code.include?('200')

  zbx_res = JSON.parse(response.body)
  raise "Zabbix API error: #{zbx_res['error']}" if zbx_res['result'].nil?

  zbx_res['result']
end
