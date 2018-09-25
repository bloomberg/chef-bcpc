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
require 'ipaddress'

def is_liberty?
  node['bcpc']['openstack_release'] == 'liberty'
end

def is_mitaka?
  node['bcpc']['openstack_release'] == 'mitaka'
end

# this method deals in strings even though API versions are numbers because
# some API versions are integers and others are floats and it would be bad
# if Ruby decided to report an API version as something like 1.10000000006584
# or 1.09999999958587
def get_api_version(service, uri_type='public')
  # render to string in case a symbol is provided
  service_str = service.to_s
  uri_type_str = uri_type.to_s

  unless ['admin', 'internal', 'public'].include? uri_type_str
    fail "#{uri_type_str} is not a valid URI type to inspect for API version, please select from admin/internal/public"
  end

  unless node['bcpc']['catalog'].keys.include? service_str
    fail "#{service_str} is not a valid service, please select from #{node['bcpc']['catalog'].keys.join('/')}"
  end

  api_version_list = node['bcpc']['catalog'][service_str]['uris'][uri_type_str].scan(/(\d+(\.\d+)?)/)

  if api_version_list.empty?
    # Glance URL should not include a version number, default to Glance API v2 in all cases
    if service_str == 'image'
      return '2'
    else
      fail "Could not derive API version for #{service_str} from #{uri_type_str} URI, please inspect service catalog"
    end
  end

  # Mitaka Horizon does not like if the version given is 2.1, just say 2
  # and let the client determine microversion
   if service_str == 'compute' && api_version_list[0][0].start_with?('2')
    return '2'
  end

  api_version_list[0][0]
end

def is_vip?
    ipaddr = `ip addr show dev #{node['bcpc']['management']['interface']}`
    return ipaddr.include? node['bcpc']['management']['vip']
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

def search_nodes(key, value)
    filter = {
      :filter_result => {
        'ipaddress' => ['ipaddress'],
        'hostname' => ['hostname'],
        'fqdn' => ['fqdn'],
        'bcpc' => ['bcpc'],
        'roles' => ['roles']
      }
    }
    if key == "recipe"
        results = search(:node, "recipes:bcpc\\:\\:#{value} AND chef_environment:#{node.chef_environment}", filter)
        results.map! { |x| x['hostname'] == node['hostname'] ? node : x }
        if not results.include?(node) and node.run_list.expand(node.chef_environment).recipes.include?("bcpc::#{value}")
            results.push(node)
        end
    elsif key == "role"
        results = search(:node, "#{key}:#{value} AND chef_environment:#{node.chef_environment}", filter)
        results.map! { |x| x['hostname'] == node['hostname'] ? node : x }
        if not results.include?(node) and node.run_list.expand(node.chef_environment).roles.include?(value)
            results.push(node)
        end
    else
        raise("Invalid search key: #{key}")
    end

    return results.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def get_all_nodes
    filter = {
      :filter_result => {
        'ipaddress' => ['ipaddress'],
        'hostname' => ['hostname'],
        'fqdn' => ['fqdn'],
        'bcpc' => ['bcpc'],
        'roles' => ['roles']
      }
    }
    results = search(:node, "recipes:bcpc AND chef_environment:#{node.chef_environment}", filter)
    results.map! { |x| x['hostname'] == node['hostname'] ? node : x }
    return results.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def get_ceph_osd_nodes
    filter = {
      :filter_result => {
        'ipaddress' => ['ipaddress'],
        'hostname' => ['hostname'],
        'fqdn' => ['fqdn'],
        'bcpc' => ['bcpc'],
        'roles' => ['roles']
      }
    }
    results = search(:node, "roles:BCPC-CephOSD AND chef_environment:#{node.chef_environment}", filter)
    results.map! { |x| x['hostname'] == node['hostname'] ? node : x }
    return results.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def get_ceph_mon_nodes
    filter = {
      :filter_result => {
        'ipaddress' => ['ipaddress'],
        'hostname' => ['hostname'],
        'fqdn' => ['fqdn'],
        'bcpc' => ['bcpc'],
        'roles' => ['roles']
      }
    }
    results = search(:node, "roles:BCPC-CephMonitor AND chef_environment:#{node.chef_environment}", filter)
    results.map! { |x| x['hostname'] == node['hostname'] ? node : x }
    return results.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def get_head_nodes
    filter = {
      :filter_result => {
        'ipaddress' => ['ipaddress'],
        'hostname' => ['hostname'],
        'fqdn' => ['fqdn'],
        'bcpc' => ['bcpc'],
        'roles' => ['roles']
      }
    }
    results = search(:node, "roles:BCPC-Headnode AND chef_environment:#{node.chef_environment}", filter)
    results.map! { |x| x['hostname'] == node['hostname'] ? node : x }
    if not results.include?(node) and node.run_list.roles.include?('BCPC-Headnode')
        results.push(node)
    end
    return results.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def get_ceph_replica_count(pool)
  replicas = [get_ceph_osd_nodes.length, node['bcpc']['ceph'][pool]['replicas']].min
  replicas = 1 if replicas < 1
  return replicas
end

def get_ceph_optimal_pg_count(pool)
  power_of_2(
    get_ceph_osd_nodes.length *
    node['bcpc']['ceph']['pgs_per_node'] /
    node['bcpc']['ceph'][pool]['replicas'] *
    node['bcpc']['ceph'][pool]['portion'] / 100)
end

def get_mysql_max_connections
  if node['bcpc']['mysql-head']['max_connections'].nil? or node['bcpc']['mysql-head']['max_connections'].zero?
     [get_head_nodes.length*150+get_all_nodes.length*10, 450].max
  else
    node['bcpc']['mysql-head']['max_connections']
  end
end

def get_bootstrap_node
    filter = {
      :filter_result => {
        'ipaddress' => ['ipaddress'],
        'hostname' => ['hostname'],
        'fqdn' => ['fqdn'],
        'bcpc' => ['bcpc'],
        'roles' => ['roles']
      }
    }
    results = search(:node, "role:BCPC-Bootstrap AND chef_environment:#{node.chef_environment}", filter)
    raise 'There is not exactly one bootstrap node found.' if results.size != 1
    results.first
end

# shuffles a list of servers deterministically to avoid stacking all connections up on a single node
# (e.g., RabbitMQ, where OpenStack will pile on to the first server in the list)
def get_shuffled_servers(server_list, prefer_local=false)
  shuffled_servers = server_list.shuffle(random: Random.new(IPAddr.new(node['bcpc']['management']['ip']).to_i))
  # prefer_local == reorder the array so that the local node appears first (remainder of array stays the same)
  if prefer_local
    # if converging on a node that is not in the given list, index will be nil, so don't modify list order
    this_server_idx = shuffled_servers.index { |x| x['bcpc']['management']['ip'] == node['bcpc']['management']['ip'] }
    shuffled_servers.insert(0, shuffled_servers.delete_at(this_server_idx)) unless this_server_idx.nil?
  end
  shuffled_servers
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

# Nearest power_of_2
def power_of_2(number)
#    result = 1
#    while (result < number) do result <<= 1 end
#    return result
  result = 1
  last_pwr = 1
  while result < number
    last_pwr = result
    result <<= 1
  end

  low_delta = number - last_pwr
  high_delta = result - number
  if high_delta > low_delta
    result = last_pwr
  end

  result
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

def calc_octets_to_drop(cidr)
  cidr = IPAddress(cidr)
  prefix = cidr.prefix.to_i
  prefix = 24 if prefix != 8 && prefix != 16
  4 - prefix / 8 # octets to drop
end

# Generates an array of classful reverse DNS zone(s) by dividing provided CIDR
# (min /24) in the form of '1.2.3.0/24'.
def calc_reverse_dns_zone(cidr)
  cidr = IPAddress(cidr)
  prefix = cidr.prefix.to_i
  prefix = 24 if prefix != 8 && prefix != 16
  subnets = cidr.subnet(prefix)
  octets = 4 - prefix / 8 # octets to drop
  subnets.map {
    |x| x.reverse.to_s.split('.')[octets, x.reverse.length].join('.') }
end

# We do not have net/ping, so just call out to system and check err value.
def ping_node(list_name, ping_node)
    sleep 3
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
    sleep 3
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

# this takes the blisteringly maddening openstack CLI JSON output of the form
# [{"Field": "x", "Value": "y"}, ...] and turns it into a regular hash
def openstack_json_to_hash(input)
  input.collect {
    |v| { v['Field'] => v['Value'] }
  }.reduce({}) {
    |target_hash, v| target_hash.merge(v)
  }
end

def generate_service_catalog_uri(svcprops, access_level)
  "#{node['bcpc']['protocol'][svcprops['project']]}://openstack.#{node['bcpc']['cluster_domain']}:#{svcprops['ports'][access_level]}/#{svcprops['uris'][access_level]}"
end

# Run temporarily with specified environment
def env(env={}, &block)
  if not block_given?
    return ENV.to_h
  end
  old_env = ENV.to_h
  ENV.replace env
  res = yield
  ENV.replace old_env
  res
end

def cmdline_env_args(environ={})
  ret = ['env']
  ret + (environ || {}).collect {|k,v|
    v = "\"#{v}\"" if v.to_s.match(/ /)
    "#{k}=#{v}"
  }.flatten
end


# Returns authentication context variables for administrative user
#
# @param username [String] target user for context
# @param filter [Proc] filter for context variables
# @param driver_precedence [Symbol] precedence of drivers to attempt [:memory, :file]
# @return [Hash] key-value map of authentication parameters
def load_user_context_vars(username,
                           filter=Proc.new {|x| x},
                           driver_precedence=[:memory, :file])
  auth = nil
  driver_precedence.each {|driver|
    auth ||= user_context(username, driver)
  }
  auth ||= {}
  val_pairs = auth.collect {|tuple| filter.call(tuple) }.flatten
  auth_vars = Hash[ *val_pairs ]
end

def calc_ip_address(cidr)
  mgmt_bitlen = (node['bcpc']['management']['cidr'].match /\d+\.\d+\.\d+\.\d+\/(\d+)/)[1].to_i
  mgmt_hostaddr = IPAddr.new(node['bcpc']['management']['ip']) << mgmt_bitlen >> mgmt_bitlen

  bitlen = (cidr.match /\d+\.\d+\.\d+\.\d+\/(\d+)/)[1].to_i
  ip = IPAddr.new(cidr)
  ip = ip >> (32 - bitlen)
  ip = ip << (32 - bitlen)
  ip = (ip | mgmt_hostaddr).to_s

  return ip
end
