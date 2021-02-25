# Copyright 2021, Bloomberg L.P.
# Copyright 2012, Piston Cloud Computing, Inc.
# Copyright 2012, OpenStack Foundation
# All Rights Reserved.
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


from nova import availability_zones
from nova import context
from nova.scheduler import filters
from oslo_log import log as logging
from oslo_utils import strutils

LOG = logging.getLogger(__name__)


class _AntiAffinityAvailabilityZoneFilter(filters.BaseHostFilter):
    """Checks the availability zone of the host if the
    availability_zone_anti_affinity is set to true.
    If the host is from a different zone than zones in the server group
    it returns true, otherwise returns false."""

    RUN_ON_REBUILD = False

    def host_passes(self, host_state, spec_obj):
        # Only invoke the filter if 'anti-affinity' and scheduler
        # hint availability_zone_affinity=true is configured
        instance_group = spec_obj.instance_group
        policy = instance_group.policy if instance_group else None
        az_hint = strutils.bool_from_string(
            spec_obj.get_scheduler_hint('availability_zone_affinity', False))
        # if the policy is not anti-affinity and availability_zone_affinity
        # scheduler hint is not true then return true and don't apply filter
        if self.policy_name != policy or not az_hint:
            return True
        # Move operations like resize can check the same source compute node
        # where the instance is. That case, AntiAffinityFilter must not return
        # the source as a non-possible destination.
        if spec_obj.instance_uuid in host_state.instances.keys():
            return True
        # list of hosts of non-deleted instances in the server group
        hosts_group_members = (
            spec_obj.instance_group.hosts if spec_obj.instance_group else [])
        # set of availability zones of the instances in the server group
        instance_group_availability_zones = set()
        host_availability_zone = availability_zones.get_host_availability_zone(
            context.get_admin_context(), host_state.host)
        for host in hosts_group_members:
            instance_group_availability_zones.add(
                availability_zones.get_host_availability_zone(
                    context.get_admin_context(), host))
        # Very old request specs don't have a full InstanceGroup with the UUID
        group_uuid = (instance_group.uuid
                      if instance_group and 'uuid' in instance_group
                      else 'n/a')
        LOG.debug("Anti-affinity-AZ-filter: check if the host %(host)s in AZ "
                  "%(host_az)s is not in the same set of AZs in server group "
                  "%(group_uuid)s",
                  {'host': host_state.host,
                   'host_az': host_availability_zone,
                   'group_uuid': group_uuid})
        return host_availability_zone not in instance_group_availability_zones


class AntiAffinityAvailabilityZoneFilter(_AntiAffinityAvailabilityZoneFilter):
    def __init__(self):
        self.policy_name = 'anti-affinity'
        super(AntiAffinityAvailabilityZoneFilter, self).__init__()