#!/usr/bin/env python3

import json


def role():

    role = {
        "name": "node",
        "description": "common role for all bcpc nodes",
        "json_class": "Chef::Role",
        "chef_type": "role",
        "run_list": [
            "recipe[bcpc::networking]",
            "recipe[bcpc::apt]",
            "recipe[bcpc::ssl]",
            "recipe[bcpc::cloud-archive]",
            "recipe[bcpc::chrony]",
            "recipe[bcpc::postfix]",
            "recipe[bcpc::common-packages]",
            "recipe[bcpc::kexec]",
            "recipe[bcpc::apport]",
            "recipe[bcpc::etckeeper]",
            "recipe[bcpc::cpupower]",
            "recipe[bcpc::getty]",
            "recipe[bcpc::hwrng]",
            "recipe[bcpc::system]"
        ]
    }

    return role


def render(data):
    print(json.dumps(data, indent=2, sort_keys=True))


if __name__ == "__main__":
    render(role())
