# Copyright (c) 2011 OpenStack Foundation
# Copyright (c) 2023 Bloomberg
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
"""
BCPC RAM Weigher.  Weigh hosts by their RAM usage.

The default OpenStack RAM weigher behavior is to first stack resource
allocations on hypervisors until a point at which all hypervisors are at
equilibrium (relative to the absolute amount of RAM allocatable to that
hypervisor). Only after this point are allocations spread evenly.

For heterogeneous clusters geared around performance, this behavior is likely
suboptimal. This modified weigher spreads allocations unconditionally by
normalizing the weight to the range [0,1] according to the capabilities of this
specific hypervisor.
"""

import nova.conf
from nova.scheduler import utils
from nova.scheduler import weights

CONF = nova.conf.CONF


class BCPCRAMWeigher(weights.BaseHostWeigher):
    minval = 0

    def weight_multiplier(self, host_state):
        """Override the weight multiplier."""
        return utils.get_weight_multiplier(
            host_state, 'ram_weight_multiplier',
            CONF.filter_scheduler.ram_weight_multiplier)

    def _weigh_object(self, host_state, weight_properties):
        """Higher weights win.  We want spreading to be the default."""
        return host_state.free_ram_mb / float(host_state.total_usable_ram_mb)
