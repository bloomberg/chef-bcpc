# Copyright (c) 2016, Red Hat Inc.
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
BCPC CPU Weigher.  Weigh hosts by their CPU usage.

The default OpenStack CPU weigher behavior is to first stack resource
allocations on hypervisors until a point at which all hypervisors are at
equilibrium (relative to the absolute number of vCPUs allocatable to that
hypervisor). Only after this point are allocations spread evenly.

For heterogeneous clusters geared around performance, this behavior is likely
suboptimal. This modified weigher spreads allocations unconditionally by
normalizing the weight to the range [0,1] according to the capabilities of this
specific hypervisor.

To account for overloads that may result after scheduling a VM, the guest
properties are also weighed. This way an overloaded hypervisor will return a
negative weight. Also to make the spread more even, the CPU idle percentage is
plugged in the weight.
"""

import nova.conf
from nova.scheduler import utils
from nova.scheduler import weights
from oslo_log import log as logging

CONF = nova.conf.CONF

LOG = logging.getLogger(__name__)


class BCPCCPUWeigher(weights.BaseHostWeigher):
    minval = 0

    def weight_multiplier(self, host_state):
        """Override the weight multiplier."""
        return utils.get_weight_multiplier(
            host_state, 'cpu_weight_multiplier',
            CONF.filter_scheduler.cpu_weight_multiplier)

    def _get_cpu_idle(self, host_state):
        """Extract CPU idle percentage from host metrics."""
        for metric in host_state.metrics.to_list():
            if metric['name'] == 'cpu.idle.percent':
                return metric['value']

        LOG.warning("Host %s has `cpu.idle.percent` missing.", host_state.host)
        return 1

    def _get_cpu_psi(self, host_state):
        """Extract CPU PSI percentage from host metrics."""
        for metric in host_state.metrics.to_list():
            if metric['name'] == 'cpu.psi.percent':
                return metric['value']

        LOG.warning("Host %s has `cpu.psi.percent` missing.", host_state.host)

        # Defaulting the value to 0 as to not influence the weight
        return 0

    def _weigh_object(self, host_state, weight_properties):
        """Higher weights win.  We want spreading to be the default."""
        vcpus_total = host_state.vcpus_total * host_state.cpu_allocation_ratio
        # The number of vCPUs that will be used on the host (VM included)
        used_vcpus = host_state.vcpus_used + weight_properties.flavor.vcpus
        cpu_idle = self._get_cpu_idle(host_state)
        cpu_psi = self._get_cpu_psi(host_state)

        # Compute the average usage of every current vCPU
        average_usage = 0
        if host_state.vcpus_used > 0:
            average_usage = (1 - cpu_idle) / host_state.vcpus_used

        # Assume the VM will use the average value for each requested vCPU
        new_idle = 1 - average_usage * used_vcpus
        # Percentage of vCPUs used after scheduling (future state)
        free_percentage = 1 - float(used_vcpus) / vcpus_total

        weight = free_percentage
        if free_percentage > 0:
            # As both idle time and PSI are time percentages, subtracting makes
            # sense to measure the remaining time availability of the CPU
            weight = free_percentage * new_idle - cpu_psi
        elif new_idle > 0:
            # When the CPU is overloaded the free percentage is negative.
            # To prevent the weight from growing when the idle time is lower,
            # the reverse if the idle percentage is used.
            weight = free_percentage * (1 / new_idle) - cpu_psi

        return weight
