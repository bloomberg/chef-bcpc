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


POLICY_ROOT = 'os_compute_api:server-properties:%s'


server_properties_policies = [
    policy.DocumentedRuleDefault(
        name=POLICY_ROOT % 'show',
        check_str=base.PROJECT_READER,
        description="Show properties for a server",
        operations=[
            {
                'path': '/servers/{server_id}/properties/{key}',
                'method': 'GET'
            }
        ],
        scope_types=['project']
    ),
    policy.DocumentedRuleDefault(
        name=POLICY_ROOT % 'update',
        check_str=base.PROJECT_MEMBER,
        description="Update an optimization for a server",
        operations=[
            {
                'path': '/servers/{server_id}/properties/{key}',
                'method': 'PUT'
            }
        ],
        scope_types=['project']
    ),
]


def list_rules():
    return server_properties_policies
