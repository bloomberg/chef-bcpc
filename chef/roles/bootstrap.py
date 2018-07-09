#!/usr/bin/env python3

import json


def role():

    role = {
        "name": "bootstrap",
        "description": "bootstrap node",
        "json_class": "Chef::Role",
        "chef_type": "role",
        "run_list": [
            "role[node]",
            "recipe[bcpc::ssl]",
            "recipe[bcpc::ssh]",
            "recipe[bcpc::file-server]"
            # "recipe[bcpc::ufw]"
            # "recipe[bcpc::backup-cluster]"
        ]
    }

    return role


def render(data):
    print(json.dumps(data, indent=2, sort_keys=True))


if __name__ == "__main__":
    render(role())
