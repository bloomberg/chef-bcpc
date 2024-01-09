"""
Copyright 2024, Bloomberg Finance L.P.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

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

    # add licenses to top level node attributes section
    licenses = hostvars.get('licenses')

    if licenses is not None:
        licenses = {'licenses': licenses}
        node_details['normal'].update(licenses)

    # add aggregate to top level node attributes section
    aggregate = hostvars.get('aggregate')

    if aggregate is not None:
        aggregate = {'aggregate': aggregate}
        node_details['normal'].update(aggregate)

    # add cpu_config to top level node attributes section
    cpu_config = hostvars.get('cpu_config')

    if cpu_config is not None:
        cpu_config = {'cpu_config': cpu_config}
        node_details['normal'].update(cpu_config)

    # add zone to top level node attributes section
    zone = hostvars.get('zone')

    if zone is not None:
        zone = {'zone': zone}
        node_details['normal'].update(zone)

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


def etcdnode_to_cnames(a, *args, **kw):

    etcd_hosts = a
    domain = args[0]

    host_to_etcdnode_cnames = {}
    for host, index in etcd_hosts.items():
        cname_fqdn = "etcdnode-{0}.{1}".format(index, domain)
        host_to_etcdnode_cnames[host] = cname_fqdn

    return host_to_etcdnode_cnames


def optimal_nvme_lbaf(a, *args, **kw):

    lbafs = a

    # Index all the LBAFs for identification
    for index, lbaf in enumerate(lbafs):
        lbaf['index'] = index

    # Order LBAFs by RP (relative performance), then largest sector size, and
    # finally smallest MS (metadata size). We want the best-performing LBA with
    # the largest sector size and which has the least amount of metadata.
    def lbaf_filter(lbaf):
        return (lbaf['rp'], -lbaf['ds'], lbaf['ms'])

    ordered_lbafs = sorted(lbafs, key=lbaf_filter)

    # Return the "best" LBAF index given the above criteria
    return ordered_lbafs[0]['index']


def is_host_multipath_enabled(host_variables):
    """Check if host is worknode or headnode chef role.

    Parameters:
    host_variables (dict): dict of hostvars[host]

    Returns:
    is_host_multipath_enabled (bool): true if worknode or headnode
    """
    for role in host_variables['run_list']:
        if role == "role[worknode]" or role == "role[headnode]":
            return True
    return False


class FilterModule(object):

    filter_map = {
        'primary_ip': primary_ip,
        'transit_interfaces': transit_interfaces,
        'update_chef_node_host_vars': update_chef_node_host_vars,
        'find_asset': find_asset,
        'osadmin': osadmin,
        'etcdnode_to_cnames': etcdnode_to_cnames,
        'optimal_nvme_lbaf': optimal_nvme_lbaf,
        'host_multipath': is_host_multipath_enabled,
    }

    def filters(self):
        return self.filter_map
