#
# Cookbook Name:: bcpc
# Library:: utils
#
# Copyright 2013, Bloomberg Finance L.P.
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

require 'openssl'
require 'base64'
require 'thread'
require 'ipaddr'

def init_config
	if not Chef::DataBag.list.key?('configs')
		Chef::Log.info "************ Creating data_bag \"configs\""
		bag = Chef::DataBag.new
		bag.name("configs")
		bag.create
	end rescue nil
	begin
		$dbi = Chef::DataBagItem.load('configs', node.chef_environment)
		$edbi = Chef::EncryptedDataBagItem.load('configs', node.chef_environment) if node['bcpc']['encrypt_data_bag']
		Chef::Log.info "============ Loaded existing data_bag_item \"configs/#{node.chef_environment}\""
	rescue
		$dbi = Chef::DataBagItem.new
		$dbi.data_bag('configs')
		$dbi.raw_data = { 'id' => node.chef_environment }
		$dbi.save
		$edbi = Chef::EncryptedDataBagItem.load('configs', node.chef_environment) if node['bcpc']['encrypt_data_bag']
		Chef::Log.info "++++++++++++ Created new data_bag_item \"configs/#{node.chef_environment}\""
	end
end

def make_config(key, value)
	init_config if $dbi.nil?
	if $dbi[key].nil?
		$dbi[key] = (node['bcpc']['encrypt_data_bag'] ? Chef::EncryptedDataBagItem.encrypt_value(value, Chef::EncryptedDataBagItem.load_secret) : value)
		$dbi.save
		$edbi = Chef::EncryptedDataBagItem.load('configs', node.chef_environment) if node['bcpc']['encrypt_data_bag']
		Chef::Log.info "++++++++++++ Creating new item with key \"#{key}\""
		return value
	else
		Chef::Log.info "============ Loaded existing item with key \"#{key}\""
		return (node['bcpc']['encrypt_data_bag'] ? $edbi[key] : $dbi[key])
	end
end

def get_config(key)
	init_config if $dbi.nil?
	Chef::Log.info  "------------ Fetching value for key \"#{key}\""
	value = node['bcpc']['encrypt_data_bag'] ? $edbi[key] : $dbi[key]
	return value
end

def get_config!(key)
        value = get_config(key)
        Chef::Application.fatal!("Failed to find value for #{key}!") if value.nil?
	return value
end

def get_all_nodes
	results = search(:node, "role:BCPC* AND chef_environment:#{node.chef_environment}")
	if results.any?{|x| x['hostname'] == node['hostname']}
		results.map!{|x| x['hostname'] == node['hostname'] ? node : x}
	else
		results.push(node)
	end
	return results
end

def get_ceph_osd_nodes
	results = search(:node, "recipes:bcpc\\:\\:ceph-work AND chef_environment:#{node.chef_environment}")
	if results.any?{|x| x['hostname'] == node[:hostname]}
		results.map!{|x| x['hostname'] == node[:hostname] ? node : x}
	else
		results.push(node)
	end
	return results
end

def get_cached_head_node_names
  headnodes = []
  begin 
    File.open("/etc/headnodes", "r") do |infile|    
      while (line = infile.gets)
        line.strip!
        if line.length>0 and not line.start_with?("#")
          headnodes << line.strip
        end
      end    
    end
  rescue Errno::ENOENT
    # assume first run   
  end
  return headnodes  
end

def get_head_nodes
  results = search(:node, "role:BCPC-Headnode AND chef_environment:#{node.chef_environment}")
  # this returns the node object for the current host before it has been set in Postgress
  results.map!{ |x| x.hostname == node.hostname ? node : x }
  return (results.empty?) ? [node] : results
end

def get_mysql_nodes
  results = search(:node, "recipes:bcpc\\:\\:mysql AND chef_environment:#{node.chef_environment}")
  results.map!{ |x| x.hostname == node.hostname ? node : x }
  return (results.empty?) ? [node] : results
end

def get_binary_server_url
  return("http://#{URI(Chef::Config['chef_server_url']).host}:8080") if node[:bcpc][:binary_server_url].nil?
  return(node[:bcpc][:binary_server_url])
end

def power_of_2(number)
	result = 1
	while (result < number) do result <<= 1 end
	return result
end

def secure_password(len=20)
	pw = String.new
	while pw.length < len
		pw << ::OpenSSL::Random.random_bytes(1).gsub(/\W/, '')
	end
	pw
end

def secure_password_alphanum_upper(len=20)
    # Chef's syntax checker doesn't like multiple exploders in same line. Sigh.
    alphanum_upper = [*'0'..'9']
    alphanum_upper += [*'A'..'Z']
    # We could probably optimize this to be in one pass if we could easily
    # handle the case where random_bytes doesn't return a rejected char.
    raw_pw = String.new
    while raw_pw.length < len
        raw_pw << ::OpenSSL::Random.random_bytes(1).gsub(/\W/, '')
    end
    pw = String.new
    while pw.length < len
        pw << alphanum_upper[raw_pw.bytes().to_a()[pw.length] % alphanum_upper.length]
    end
    pw
end

def ceph_keygen()
    key = "\x01\x00"
    key += ::OpenSSL::Random.random_bytes(8)
    key += "\x10\x00"
    key += ::OpenSSL::Random.random_bytes(16)
    Base64.encode64(key).strip
end

def float_host(*args)
  #"f-" + args.join('.')
  args.join('.')
end

def storage_host(*args)
  #"s-" + args.join('.')
  args.join('.')
end

# requires cidr in form '1.2.3.0/24', where 1.2.3.0 is a dotted quad ip4 address 
# and 24 is a number of netmask bits (e.g. 8, 16, 24)
def calc_reverse_dns_zone(cidr)

  # Validate and parse cidr as an IP
  cidr_ip = IPAddr.new(cidr) # Will throw exception if cidr is bad.

  # Pull out the netmask and throw an error if we can't find it.
  netmask = cidr.split('/')[1].to_i
  raise ("Couldn't find netmask portion of CIDR in #{cidr}.") unless netmask > 0  # nil.to_i == 0, "".to_i == 0  Should always be one of [8,16,24]

  # Knock off leading quads in the reversed IP as specified by the netmask.  (24 ==> Remove one quad, 16 ==> remove two quads, etc)
  # So for example: 192.168.100.0, we'd expect the following input/output:
  # Netmask:   8  => 192.in-addr.arpa         (3 quads removed)
  #           16  => 168.192.in-addr.arpa     (2 quads removed)
  #           24  => 100.168.192.in-addr.arpa (1 quad removed)
  
  reverse_ip = cidr_ip.reverse   # adds .in-addr.arpa automatically
  (4 - (netmask.to_i/8)).times{ reverse_ip = reverse_ip.split('.')[1..-1].join('.')  }  # drop off element 0 each time through

  return reverse_ip

end

