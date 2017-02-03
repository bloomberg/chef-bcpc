#
# Cookbook Name:: bcpc
# Recipe:: powerdns-nova
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

if node['bcpc']['enabled']['dns']
  include_recipe 'bcpc::nova-head'

  # this template replaces several old ruby_block resources and pre-seeds fixed entries into a template file to be loaded into MySQL
  fixed_records_file = '/tmp/powerdns_generate_fixed_records.sql'
  template fixed_records_file do
    source 'powerdns_generate_fixed_records.sql.erb'
    owner 'root'
    group 'root'
    mode 00644
    variables({
      :database_name      => node['bcpc']['dbname']['pdns'],
      :cluster_domain     => node['bcpc']['cluster_domain'],
      :reverse_fixed_zone => (node['bcpc']['fixed']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['fixed']['cidr']))
    })
    notifies :run, 'ruby_block[powerdns-load-fixed-records]', :immediately
  end

  ruby_block 'powerdns-load-fixed-records' do
    block do
      system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot #{node['bcpc']['dbname']['pdns']} < #{fixed_records_file}"
    end
    action :nothing
  end

  # dns_fill.py handles creating CNAMEs based on instance and tenancy
  template '/usr/local/etc/dns_fill.yml' do
    source 'pdns.dns_fill.yml.erb'
    owner 'pdns'
    group 'root'
    mode 00640
  end

  cookbook_file '/usr/local/bin/dns_fill.py' do
    source 'dns_fill.py'
    mode '00755'
    owner 'pdns'
    group 'root'
  end

  cron 'run dns_fill' do
    minute '*/5'
    hour '*'
    weekday '*'
    command '/usr/local/bin/if_vip /usr/local/bin/dns_fill.py -c /usr/local/etc/dns_fill.yml run'
  end
end
