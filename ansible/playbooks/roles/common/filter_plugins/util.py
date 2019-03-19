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
        if facts.get(interface, {}).get('macaddress', None) == macaddress:
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


def find_asset(a, *args, **kw):

    asset_to_find = a
    assets = args[0]

    for asset in assets:
        if asset['name'] == asset_to_find:
            return asset

    raise ValueError("could not find {}".format(asset_to_find))


def osadmin(a, *args, **kw):

    cloud_vars = a
    chef = cloud_vars['chef']
    cloud = cloud_vars['cloud']

    databags = chef['databags']
    config = [databag for databag in databags if databag['id'] == 'config'][0]

    os_username = 'admin'
    os_password = config['openstack'][os_username]['password']
    os_region_name = cloud['region']
    os_auth_url = "https://{}:35357/v3".format(cloud['fqdn'])

    return {
        'OS_PROJECT_DOMAIN_ID': 'default',
        'OS_USER_DOMAIN_ID': 'default',
        'OS_PROJECT_NAME': 'admin',
        'OS_USERNAME': os_username,
        'OS_PASSWORD': os_password,
        'OS_AUTH_URL': os_auth_url,
        'OS_REGION_NAME': os_region_name,
        'OS_IDENTITY_API_VERSION': 3,
        'OS_VOLUME_API_VERSION': 3
    }


class FilterModule(object):

    filter_map = {
        'primary_ip': primary_ip,
        'transit_interfaces': transit_interfaces,
        'update_chef_node_host_vars': update_chef_node_host_vars,
        'find_asset': find_asset,
        'osadmin': osadmin
    }

    def filters(self):
        return self.filter_map
