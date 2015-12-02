#
# Cookbook Name:: bcpc-foundation
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

require 'base64'
require 'ipaddr'
require 'openssl'
require 'securerandom'
require 'thread'

# this horrid little blob was stolen from https://tickets.opscode.com/browse/CHEF-2756
# to allow accessing the DSL inside ruby_block resources, so that resources that depend
# on search results can be created at runtime
require 'chef/dsl/data_query'
require 'chef/dsl/include_recipe'
require 'chef/dsl/platform_introspection'
require 'chef/dsl/recipe'

class Chef
  class Resource
    class RubyBlock
      include Chef::DSL::DataQuery
      include Chef::DSL::IncludeRecipe
      include Chef::DSL::PlatformIntrospection
      include Chef::DSL::Recipe
    end
  end
end

def is_vip?
    ipaddr = Mixlib::ShellOut("ip addr show dev #{node['bcpc']['management']['interface']}").run_command
    return ipaddr.stdout.include? node['bcpc']['management']['vip']
end

def init_config
    if not Chef::DataBag.list.key?('configs')
        Chef::Log.info("************ Creating data_bag \"configs\"")
        bag = Chef::DataBag.new
        bag.name("configs")
        bag.save
    end rescue nil
    begin
        $dbi = Chef::DataBagItem.load('configs', node.chef_environment)
        $edbi = Chef::EncryptedDataBagItem.load('configs', node.chef_environment) if node['bcpc']['enabled']['encrypt_data_bag']
        Chef::Log.info("============ Loaded existing data_bag_item \"configs/#{node.chef_environment}\"")
    rescue
        $dbi = Chef::DataBagItem.new
        $dbi.data_bag('configs')
        $dbi.raw_data = { 'id' => node.chef_environment }
        $dbi.save
        $edbi = Chef::EncryptedDataBagItem.load('configs', node.chef_environment) if node['bcpc']['enabled']['encrypt_data_bag']
        Chef::Log.info("++++++++++++ Created new data_bag_item \"configs/#{node.chef_environment}\"")
    end
end

def make_config(key, value, force=false)
    init_config if $dbi.nil?
    if $dbi[key].nil? or force
        $dbi[key] = (node['bcpc']['enabled']['encrypt_data_bag']) ? Chef::EncryptedDataBagItem.encrypt_value(value, Chef::EncryptedDataBagItem.load_secret) : value
        $dbi.save
        $edbi = Chef::EncryptedDataBagItem.load('configs', node.chef_environment) if node['bcpc']['enabled']['encrypt_data_bag']
        Chef::Log.info("++++++++++++ Creating new item with key \"#{key}\"")
        return value
    else
        Chef::Log.info("============ Loaded existing item with key \"#{key}\"")
        return (node['bcpc']['enabled']['encrypt_data_bag']) ? $edbi[key] : $dbi[key]
    end
end

def make_config_from_cmd(key, command, force=false)
  mlscmd = Mixlib::ShellOut.new(command)
  mlscmd.run_command
  mlscmd.error!
  make_config(key, mlscmd.stdout.strip, force)
end

def config_defined(key)
    init_config if $dbi.nil?
    Chef::Log.info("------------ Checking if key \"#{key}\" is defined")
    result = (node['bcpc']['enabled']['encrypt_data_bag']) ? $edbi[key] : $dbi[key]
    return !result.nil?
end

def get_config(key)
    init_config if $dbi.nil?
    Chef::Log.info("------------ Fetching value for key \"#{key}\"")
    result = (node['bcpc']['enabled']['encrypt_data_bag']) ? $edbi[key] : $dbi[key]
    raise "No config found for get_config(#{key})!!!" if result.nil?
    return result
end

def safe_parse_json(json)
  begin
    JSON.parse(json)
  rescue JSON::ParserError
    fail "Unable to parse supplied JSON: #{json}"
  end
end

###########################
# IMPORTANT NOTE
# #########################
# If invoking any of the below search functions in a recipe,
# wrap in a lazy {} block or use inside a ruby_block
# so that you will not be bitten by compile time vs runtime issues

def get_nodes_with_recipe(value)
  escaped_value = value.gsub(':', '\:')
  # if just searching for a cookbook, also look for ::default
  search_pattern = if value.include? ':'
    "recipes:#{escaped_value}"
  else
    "(recipes:#{escaped_value} OR recipes:#{escaped_value}\\:\\:default)"
  end
  search_pattern << " AND chef_environment:#{node.chef_environment}"

  if Chef::Config[:solo]
    fail 'BCPC cookbooks require a functional Chef Server installation.'
  else
    # the map replaces the node that matches the current node with the node object,
    # which allows get_x_nodes.include?(node) to work in recipes
    search(:node, search_pattern).map{ |x| x.hostname == node.hostname ? node : x }.sort{ |x,y| x.hostname <=> y.hostname }
  end
end

# this gets all nodes except the bootstrap node
def get_all_nodes
  get_nodes_with_recipe('component-bcpc-node-common')
end

def get_ceph_osd_nodes
  get_nodes_with_recipe('bcpc-ceph::osd')
end

def get_head_nodes
  get_nodes_with_recipe('role-bcpc-node-head')
end

def get_monitor_nodes
  get_nodes_with_recipe('role-bcpc-node-monitor')
end

def get_bootstrap_node
  results = get_nodes_with_recipe('role-bcpc-bootstrap')
  raise 'There is not exactly one bootstrap node found.' if results.size != 1
  results.first
end

# shuffles a list of servers deterministically to avoid stacking all connections up on a single node
# (e.g., RabbitMQ, where OpenStack will pile on to the first server in the list)
def get_shuffled_servers(server_list)
  server_list.shuffle(random: Random.new(IPAddr.new(node['bcpc']['management']['ip']).to_i))
end

def get_cached_head_node_names
    headnodes = []
    begin
        File.open("/etc/headnodes", "r") do |infile|
            while line = infile.gets
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

def generate_uuid
  SecureRandom.uuid()
end

def ceph_keygen()
    key = "\x01\x00"
    key += ::OpenSSL::Random.random_bytes(8)
    key += "\x10\x00"
    key += ::OpenSSL::Random.random_bytes(16)
    Base64.encode64(key).strip
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
    (4 - (netmask.to_i/8)).times { reverse_ip = reverse_ip.split('.')[1..-1].join('.') } # drop off element 0 each time through

    return reverse_ip

end

# We do not have net/ping, so just call out to system and check err value.
def ping_node(list_name, ping_node)
    Open3.popen3("ping -c1 #{ping_node}") { |stdin, stdout, stderr, wait_thr|
        rv = wait_thr.value
        if rv == 0
            Chef::Log.info("Success pinging #{ping_node}")
            return
        end
        Chef::Log.warn("Failure pinging #{ping_node} - #{rv} - #{stdout.read} - #{stderr.read}")
    }
    raise ("Network test failed: #{list_name} unreachable")
end

def ping_node_list(list_name, ping_list, fast_exit=true)
    success = false
    ping_list.each do |ping_node|
        Open3.popen3("ping -c1 #{ping_node}") { |stdin, stdout, stderr, wait_thr|
            rv = wait_thr.value
            if rv == 0
                Chef::Log.info("Success pinging #{ping_node}")
                return unless not fast_exit
                success = true
            else
                Chef::Log.warn("Failure pinging #{ping_node} - #{rv} - #{stdout.read} - #{stderr.read}")
            end
        }
    end
    if not success
        raise ("Network test failed: #{list_name} unreachable")
    end
end

def generate_vrrp_vrid()
    init_config if $dbi.nil?
    dbi = Chef::DataBagItem.load('configs', node.chef_environment)
    a =  dbi.select {|key| /^keepalived-.*router-id$/.match(key)}.values
    exclusions = a.collect {|a| [a-1, a, a+1]}.flatten
    results = (1..254).to_a - exclusions
    raise "Unable to generate unique VRID" if results.empty?
    results.first
end
