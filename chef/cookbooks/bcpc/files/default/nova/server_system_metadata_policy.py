# Copyright 2016 Cloudbase Solutions Srl
# Copyright 2023, Bloomberg L.P.
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

from oslo_policy import policy

from nova.policies import base


POLICY_ROOT = 'os_compute_api:server-system-metadata:%s'


server_system_metadata_policies = [
    policy.DocumentedRuleDefault(
        name=POLICY_ROOT % 'index',
        check_str=base.PROJECT_READER,
        description="List all system metadata of a server",
        operations=[
            {
                'path': '/servers/{server_id}/system-metadata',
                'method': 'GET'
            }
        ],
        scope_types=['project']
    ),
    policy.DocumentedRuleDefault(
        name=POLICY_ROOT % 'show',
        check_str=base.PROJECT_READER,
        description="Show system metadata for a server",
        operations=[
            {
                'path': '/servers/{server_id}/system-metadata/{key}',
                'method': 'GET'
            }
        ],
        scope_types=['project']
    ),
    policy.DocumentedRuleDefault(
        name=POLICY_ROOT % 'create',
        check_str=base.PROJECT_MEMBER,
        description="Create system metadata for a server",
        operations=[
            {
                'path': '/servers/{server_id}/system-metadata',
                'method': 'POST'
            }
        ],
        scope_types=['project']
    ),
    policy.DocumentedRuleDefault(
        name=POLICY_ROOT % 'update_all',
        check_str=base.PROJECT_MEMBER,
        description="Replace system metadata for a server",
        operations=[
            {
                'path': '/servers/{server_id}/system-metadata',
                'method': 'PUT'
            }
        ],
        scope_types=['project']
    ),
    policy.DocumentedRuleDefault(
        name=POLICY_ROOT % 'update',
        check_str=base.PROJECT_MEMBER,
        description="Update system metadata from a server",
        operations=[
            {
                'path': '/servers/{server_id}/system-metadata/{key}',
                'method': 'PUT'
            }
        ],
        scope_types=['project']
    ),
    policy.DocumentedRuleDefault(
        name=POLICY_ROOT % 'delete',
        check_str=base.PROJECT_MEMBER,
        description="Delete system metadata from a server",
        operations=[
            {
                'path': '/servers/{server_id}/system-metadata/{key}',
                'method': 'DELETE'
            }
        ],
        scope_types=['project']
    ),
]


def list_rules():
    return server_system_metadata_policies
