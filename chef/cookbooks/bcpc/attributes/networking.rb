###############################################################################
# networking
###############################################################################

require 'ipaddr'
require 'ipaddress'

default['bcpc']['networking']['topology'] = {
  "default_rack": "1",
  "networks": {
    "primary": {"cidr": "10.121.84.0/22", 'dev': 'eth1'},
    "storage": {"cidr": "10.121.88.0/22", 'dev': 'eth2'}
  },
  "racks": {
    "1": {
      "bgp_as": 64111,
      "networks": {
        "primary": { "cidr": "10.121.84.0/28", "gateway": "10.121.84.1" },
        "storage": { "cidr": "10.121.88.0/28", "gateway": "10.121.88.1" }
      }
    },
    "2": {
      "bgp_as": 64112,
      "networks": {
        "primary": { "cidr": "10.121.85.0/28", "gateway": "10.121.85.1" },
        "storage": { "cidr": "10.121.89.0/28", "gateway": "10.121.89.1" }
      }
    },
    "3": {
      "bgp_as": 64113,
      "networks": {
        "primary": { "cidr": "10.121.86.0/28", "gateway": "10.121.86.1" },
        "storage": { "cidr": "10.121.90.0/28", "gateway": "10.121.90.1" }
      }
    }
  }
}

# try to get node information via the hostname
# eg. ob-cloud-r(01)(a)n(01) = rack_id,pod_id,node_id
#

if match = node['hostname'].match(/.*r(\d+)(\w+)?n(\d+)$/i)
  rack_id,pod_id,node_id = match.captures
else
  rack_id = default['bcpc']['networking']['topology']['default_rack']
end

default['bcpc']['networking']['rack_id'] = rack_id
# get the rack that this node belongs to
#
rack = default['bcpc']['networking']['topology']['racks'][rack_id]

rack['networks'].each do |net,spec|

  topology = default['bcpc']['networking']['topology']
  network = topology['networks'][net]
  prefix = IPAddress(spec['cidr']).prefix.to_i
  primary_ip = node['ipaddress']

  if net == 'primary'

    default['bcpc']['networking']['ifaces'][net]['ip'] = primary_ip
    default['bcpc']['networking']['ifaces'][net]['prefix'] = prefix
    default['bcpc']['networking']['ifaces'][net]['gw'] = spec['gateway']
    default['bcpc']['networking']['ifaces'][net]['dev'] = network['dev']

  else

    host_id = (IPAddr.new(primary_ip) << prefix >> prefix).to_i
    ip_network = IPAddr.new(spec['cidr']) >> (32 - prefix) << (32 - prefix)
    ipaddress = (ip_network | host_id).to_s

    default['bcpc']['networking']['ifaces'][net]['ip'] = ipaddress
    default['bcpc']['networking']['ifaces'][net]['prefix'] = prefix
    default['bcpc']['networking']['ifaces'][net]['dev'] = network['dev']
    default['bcpc']['networking']['ifaces'][net]['route'] = {
      'to' => network['cidr'], 'via' => spec['gateway']
    }

  end
end
