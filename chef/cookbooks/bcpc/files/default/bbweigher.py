# Copyright (c) 2017 Bloomberg L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
"""
Bloomberg custom weigher that gives high priority to hosts with less than
1:1 CPU commit.
"""

import math

from nova.scheduler import weights
from oslo_log import log as logging

LOG = logging.getLogger(__name__)

class BBWeigher(weights.BaseHostWeigher):
    minval = 0

    def _weigh_object(self, host_state, weight_properties):
        memory_weight = math.sqrt(max(0.0, host_state.free_ram_mb/1024.0))
        host_vcpu_limit = host_state.limits.get('vcpu', 0.0)
        host_vcpu_threshold = host_vcpu_limit - host_state.vcpus_used
        cpu_weight = max(0.0, host_vcpu_threshold)

        # if host is not overcommitted, strongly favor it
        if host_state.vcpus_total > host_state.vcpus_used:
            cpu_weight = (host_state.vcpus_total - host_state.vcpus_used)**2

        # amplified to be on the same scale as the RAM weigher
        bb_weight = (memory_weight + cpu_weight)**2

        LOG.debug("BBWEIGHER: HOST %s: %f" % (host_state.nodename, bb_weight))

        return bb_weight
