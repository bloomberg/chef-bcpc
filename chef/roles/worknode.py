#!/usr/bin/env python3

import json


def role():

    role = {
        "name": "worknode",
        "description": "cloud compute services",
        "json_class": "Chef::Role",
        "chef_type": "role",
        "run_list": [
            "role[node]",
            "recipe[bcpc::bird]",
            "recipe[bcpc::etcd-proxy]",
            "recipe[bcpc::calico-work]",
            "recipe[bcpc::ceph-osd]",
            "recipe[bcpc::nova-compute]"
        ]
    }

    return role


def render(data):
    print(json.dumps(data, indent=2, sort_keys=True))


if __name__ == "__main__":
    render(role())
