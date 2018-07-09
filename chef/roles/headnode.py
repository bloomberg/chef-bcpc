#!/usr/bin/env python3

import json


def role():

    role = {
        "name": "headnode",
        "description": "cloud infrastructure services",
        "json_class": "Chef::Role",
        "chef_type": "role",
        "run_list": [
            "role[node]",
            "recipe[bcpc::ssh]",
            "recipe[bcpc::bird]",
            "recipe[bcpc::etcd-member]",
            "recipe[bcpc::rabbitmq]",
            "recipe[bcpc::memcached]",
            "recipe[bcpc::unbound]",
            "recipe[bcpc::consul]",
            "recipe[bcpc::ceph-mon]",
            "recipe[bcpc::ceph-mgr]",
            "recipe[bcpc::ceph-osd]",
            "recipe[bcpc::haproxy]",
            "recipe[bcpc::mysql]",
            "recipe[bcpc::apache2]",
            "recipe[bcpc::keystone]",
            "recipe[bcpc::glance]",
            "recipe[bcpc::neutron-head]",
            "recipe[bcpc::nova-head]",
            "recipe[bcpc::cinder]",
            "recipe[bcpc::horizon]",
            "recipe[bcpc::os-quota]",
            "recipe[bcpc::flavors]"
            # "recipe[bcpc::mysql-backup]"
        ]
    }

    return role


def render(data):
    print(json.dumps(data, indent=2, sort_keys=True))


if __name__ == "__main__":
    render(role())
