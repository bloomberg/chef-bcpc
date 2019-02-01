from __future__ import (absolute_import, division, print_function)

__metaclass__ = type

import ipaddress

def primary_ip(a, *args, **kw):
  for transit in a:
    if 'primary' in transit and transit['primary'] is True:
      return ipaddress.IPv4Interface(transit['ip']).ip

  return args[0]['ansible_host']

def transit_interfaces(a, *args, **kw):
  interfaces = []
  ansible_facts = args[0]

  for transit in a:
    interface = find_interface(facts=ansible_facts,
                               macaddress=transit['mac'])
    transit['name'] = interface['device']
    interfaces.append(transit)

  return interfaces

def find_interface(facts, macaddress):

  interfaces = facts['interfaces']

  for interface in interfaces:
    if interface == 'lo':
      continue
    if facts.get(interface,{}).get('macaddress', None) == macaddress:
      return facts[interface]

  raise ValueError("could not find interface with mac: " + macaddress)

def update_chef_node_host_vars(a, *args, **kw):

    node_details = a
    hostvars = args[0]

    interfaces = hostvars['interfaces']

    node_details['normal']['service_ip'] = interfaces['service']['ip']
    node_details['normal']['host_vars'] = {}
    node_details['normal']['host_vars'].update({'interfaces': interfaces})

    return node_details

class FilterModule(object):

  filter_map = {
    'primary_ip': primary_ip,
    'transit_interfaces': transit_interfaces,
    'update_chef_node_host_vars': update_chef_node_host_vars,
  }

  def filters(self):
    return self.filter_map
