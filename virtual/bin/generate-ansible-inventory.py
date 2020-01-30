#!/usr/bin/env python

"""
Copyright 2018, Bloomberg Finance L.P.

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

from __future__ import print_function

import os
import yaml


def is_valid_file(parser, arg):

    if not os.path.isfile(arg):
        parser.error('The file {} does not exist!'.format(arg))
    else:
        return arg


def parse_ssh_config(ssh_config_file):

    hosts = []

    with open(ssh_config_file) as f:
        lines = f.readlines()
        host = {}

        for line in lines:

            line = line.strip()

            if line != '':
                key, value = line.split(' ')
                host[key] = value
            else:
                hosts.append(host)
                host = {}

    return hosts


def parse_topology_config(topology_config_file):

    with open(topology_config_file) as f:
        return yaml.safe_load(f)


def get_group_hosts(group, ssh_config, nodes):

    group_hosts = {}

    for host in ssh_config:

        node = list(
          filter(
            lambda node: host['Host'] == node.get('name', node['host']), nodes
          )
        )

        if len(node) > 2:
            msg = "more than 1 node with the hostname {host} found"
            msg = msg.format(host=host)
            raise ValueError(msg)

        node = node[0]

        if node['group'] == group:

            host_vars = node['host_vars']
            host_vars.update({
              'ansible_host': host['HostName'],
              'ansible_port': host['Port'],
            })

            group_hosts.update({node['host']: host_vars})

    return group_hosts


def get_inventory_data(ssh_config, nodes):

    inventory = {
        'all': {
              'children': {
                    'localhost': {
                        'hosts': {
                            '127.0.0.1': {'ansible_connection': 'local'}
                        }
                    },
              }
        }
    }

    cloud = {'children': {}}

    for group in [n['group'] for n in nodes]:

        hosts = get_group_hosts(group, ssh_config, nodes)

        if len(hosts):
            cloud['children'].update({group: {'hosts': hosts}})

        if len(cloud['children']):
            inventory['all']['children'].update({'cloud': cloud})

    return inventory


def main():

    import argparse

    desc = "Generate Ansible Inventory File"
    parser = argparse.ArgumentParser(description=desc)

    parser.add_argument(
        "--ssh-config",
        dest="ssh_conf",
        required=True,
        help="Path to SSH config file",
        metavar="FILE",
        type=lambda x: is_valid_file(parser, x)
    )

    parser.add_argument(
        "--topology-config",
        dest="topology_conf",
        required=True,
        help="Path to topology config file",
        metavar="FILE",
        type=lambda x: is_valid_file(parser, x)
    )

    args = parser.parse_args()

    ssh_config = parse_ssh_config(args.ssh_conf)
    topology = parse_topology_config(args.topology_conf)
    inventory_data = get_inventory_data(ssh_config, topology['nodes'])

    print(yaml.dump(inventory_data, default_flow_style=False, indent=2))


if __name__ == "__main__":
    main()
