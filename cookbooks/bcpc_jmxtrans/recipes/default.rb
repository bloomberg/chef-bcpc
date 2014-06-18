#
# Cookbook Name:: bcpc_jmxtrans
# Recipe:: default
#
# Copyright 2014, Bloomberg L.P
#
# All rights reserved - Do Not Redistribute
#

#
# Logic to include the node ip so that the JMXTrans JSON file can be genereated correctly
#
vservers = node['jmxtrans']['servers'].dup

vservers.each do |vserver|
  vserver['name']=node['bcpc']['management']['ip']
end

node.override['jmxtrans']['servers']=vservers

#
# Logic to populate the graphite parameters if they are not set
#

if node['jmxtrans']['graphite']['host'].nil? || node['jmxtrans']['graphite']['host'] == 'graphite'
   node.default['jmxtrans']['graphite']['host'] = node['bcpc']['management']['vip']
   node.default['jmxtrans']['graphite']['port'] = node['bcpc']['graphite']['relay-port']
end

#
# Logic to set the URL from where the jmxtrans software need to be downloaded
#
sw_download_url = get_binary_server_url
node.default['jmxtrans']['url'] = "#{sw_download_url}"+"#{node['jmxtrans']['sw']}"

include_recipe 'jmxtrans'
