# -*- encoding: utf-8 -*-
# Copyright (c) 2015 b<>com
#
# Authors: Jean-Emile DARTOIS <jean-emile.dartois@b-com.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import time

from novaclient import api_versions
from oslo_log import log

import glanceclient.exc as glexceptions
import novaclient.exceptions as nvexceptions

from watcher.common import clients
from watcher.common import exception
from watcher.common import utils
from watcher import conf

LOG = log.getLogger(__name__)

CONF = conf.CONF


class NovaHelper(object):

    def __init__(self, osc=None):
        """:param osc: an OpenStackClients instance"""
        self.osc = osc if osc else clients.OpenStackClients()
        self.neutron = self.osc.neutron()
        self.cinder = self.osc.cinder()
        self.nova = self.osc.nova()
        self.glance = self.osc.glance()

    def get_compute_node_list(self):
        return self.nova.hypervisors.list()

    def get_compute_node_by_id(self, node_id):
        """Get compute node by ID (*not* UUID)"""
        # We need to pass an object with an 'id' attribute to make it work
        return self.nova.hypervisors.get(utils.Struct(id=node_id))

    def get_compute_node_by_hostname(self, node_hostname):
        """Get compute node by hostname"""
        try:
            hypervisors = [hv for hv in self.get_compute_node_list()
                           if hv.service['host'] == node_hostname]
            if len(hypervisors) != 1:
                # TODO(hidekazu)
                # this may occur if VMware vCenter driver is used
                raise exception.ComputeNodeNotFound(name=node_hostname)
            else:
                compute_nodes = self.nova.hypervisors.search(
                    hypervisors[0].hypervisor_hostname)
                if len(compute_nodes) != 1:
                    raise exception.ComputeNodeNotFound(name=node_hostname)

                return self.get_compute_node_by_id(compute_nodes[0].id)
        except Exception as exc:
            LOG.exception(exc)
            raise exception.ComputeNodeNotFound(name=node_hostname)

    def get_instance_list(self):
        return self.nova.servers.list(search_opts={'all_tenants': True},
                                      limit=-1)

    def get_flavor_list(self):
        return self.nova.flavors.list(**{'is_public': None})

    def get_service(self, service_id):
        return self.nova.services.find(id=service_id)

    def get_aggregate_list(self):
        return self.nova.aggregates.list()

    def get_aggregate_detail(self, aggregate_id):
        return self.nova.aggregates.get(aggregate_id)

    def get_availability_zone_list(self):
        return self.nova.availability_zones.list(detailed=True)

    def get_service_list(self):
        return self.nova.services.list(binary='nova-compute')

    def find_instance(self, instance_id):
        return self.nova.servers.get(instance_id)

    def confirm_resize(self, instance, previous_status, retry=60):
        instance.confirm_resize()
        instance = self.nova.servers.get(instance.id)
        while instance.status != previous_status and retry:
            instance = self.nova.servers.get(instance.id)
            retry -= 1
            time.sleep(1)
        if instance.status == previous_status:
            return True
        else:
            LOG.debug("confirm resize failed for the "
                      "instance %s", instance.id)
            return False

    def wait_for_volume_status(self, volume, status, timeout=60,
                               poll_interval=1):
        """Wait until volume reaches given status.

        :param volume: volume resource
        :param status: expected status of volume
        :param timeout: timeout in seconds
        :param poll_interval: poll interval in seconds
        """
        start_time = time.time()
        while time.time() - start_time < timeout:
            volume = self.cinder.volumes.get(volume.id)
            if volume.status == status:
                break
            time.sleep(poll_interval)
        else:
            raise Exception("Volume %s did not reach status %s after %d s"
                            % (volume.id, status, timeout))
        return volume.status == status

    def watcher_non_live_migrate_instance(self, instance_id, dest_hostname,
                                          retry=120):
        """This method migrates a given instance

        This method uses the Nova built-in migrate()
        action to do a migration of a given instance.
        For migrating a given dest_hostname, Nova API version
        must be 2.56 or higher.

        It returns True if the migration was successful,
        False otherwise.

        :param instance_id: the unique id of the instance to migrate.
        :param dest_hostname: the name of the destination compute node, if
                              destination_node is None, nova scheduler choose
                              the destination host
        """
        LOG.debug(
            "Trying a cold migrate of instance '%s' ", instance_id)

        # Looking for the instance to migrate
        instance = self.find_instance(instance_id)
        if not instance:
            LOG.debug("Instance %s not found !", instance_id)
            return False
        else:
            host_name = getattr(instance, "OS-EXT-SRV-ATTR:host")
            LOG.debug(
                "Instance %(instance)s found on host '%(host)s'.",
                {'instance': instance_id, 'host': host_name})

            previous_status = getattr(instance, 'status')

            if (dest_hostname and
                    not self._check_nova_api_version(self.nova, "2.56")):
                LOG.error("For migrating a given dest_hostname,"
                          "Nova API version must be 2.56 or higher")
                return False

            instance.migrate(host=dest_hostname)
            instance = self.nova.servers.get(instance_id)

            while (getattr(instance, 'status') not in
                   ["VERIFY_RESIZE", "ERROR"] and retry):
                instance = self.nova.servers.get(instance.id)
                time.sleep(2)
                retry -= 1
            new_hostname = getattr(instance, 'OS-EXT-SRV-ATTR:host')

            if (host_name != new_hostname and
                    instance.status == 'VERIFY_RESIZE'):
                if not self.confirm_resize(instance, previous_status):
                    return False
                LOG.debug(
                    "cold migration succeeded : "
                    "instance %(instance)s is now on host '%(host)s'.",
                    {'instance': instance_id, 'host': new_hostname})
                return True
            else:
                LOG.debug(
                    "cold migration for instance %s failed", instance_id)
                return False

    def resize_instance(self, instance_id, flavor, retry=120):
        """This method resizes given instance with specified flavor.

        This method uses the Nova built-in resize()
        action to do a resize of a given instance.

        It returns True if the resize was successful,
        False otherwise.

        :param instance_id: the unique id of the instance to resize.
        :param flavor: the name or ID of the flavor to resize to.
        """
        LOG.debug(
            "Trying a resize of instance %(instance)s to "
            "flavor '%(flavor)s'",
            {'instance': instance_id, 'flavor': flavor})

        # Looking for the instance to resize
        instance = self.find_instance(instance_id)

        flavor_id = None

        try:
            flavor_id = self.nova.flavors.get(flavor)
        except nvexceptions.NotFound:
            flavor_id = [f.id for f in self.nova.flavors.list() if
                         f.name == flavor][0]
        except nvexceptions.ClientException as e:
            LOG.debug("Nova client exception occurred while resizing "
                      "instance %s. Exception: %s", instance_id, e)

        if not flavor_id:
            LOG.debug("Flavor not found: %s", flavor)
            return False

        if not instance:
            LOG.debug("Instance not found: %s", instance_id)
            return False

        instance_status = getattr(instance, 'OS-EXT-STS:vm_state')
        LOG.debug(
            "Instance %(id)s is in '%(status)s' status.",
            {'id': instance_id, 'status': instance_status})

        instance.resize(flavor=flavor_id)
        while getattr(instance,
                      'OS-EXT-STS:vm_state') != 'resized' \
                and retry:
            instance = self.nova.servers.get(instance.id)
            LOG.debug(
                'Waiting the resize of {0}  to {1}'.format(
                    instance, flavor_id))
            time.sleep(1)
            retry -= 1

        instance_status = getattr(instance, 'status')
        if instance_status != 'VERIFY_RESIZE':
            return False

        instance.confirm_resize()

        LOG.debug("Resizing succeeded : instance %s is now on flavor "
                  "'%s'.", instance_id, flavor_id)

        return True

    def live_migrate_instance(self, instance_id, dest_hostname, retry=120):
        """This method does a live migration of a given instance

        This method uses the Nova built-in live_migrate()
        action to do a live migration of a given instance.

        It returns True if the migration was successful,
        False otherwise.

        :param instance_id: the unique id of the instance to migrate.
        :param dest_hostname: the name of the destination compute node, if
                              destination_node is None, nova scheduler choose
                              the destination host
        """
        LOG.debug(
            "Trying a live migrate instance %(instance)s ",
            {'instance': instance_id})

        # Looking for the instance to migrate
        instance = self.find_instance(instance_id)
        if not instance:
            LOG.debug("Instance not found: %s", instance_id)
            return False
        else:
            host_name = getattr(instance, 'OS-EXT-SRV-ATTR:host')
            LOG.debug(
                "Instance %(instance)s found on host '%(host)s'.",
                {'instance': instance_id, 'host': host_name})

            # From nova api version 2.25(Mitaka release), the default value of
            # block_migration is None which is mapped to 'auto'.
            instance.live_migrate(host=dest_hostname)

            instance = self.nova.servers.get(instance_id)

            # NOTE: If destination host is not specified for live migration
            # let nova scheduler choose the destination host.
            if dest_hostname is None:
                while (instance.status not in ['ACTIVE', 'ERROR'] and retry):
                    instance = self.nova.servers.get(instance.id)
                    LOG.debug(
                        'Waiting the migration of {0}'.format(instance.id))
                    time.sleep(1)
                    retry -= 1
                new_hostname = getattr(instance, 'OS-EXT-SRV-ATTR:host')

                if host_name != new_hostname and instance.status == 'ACTIVE':
                    LOG.debug(
                        "Live migration succeeded : "
                        "instance %s is now on host '%s'.", (
                            instance_id, new_hostname))
                    return True
                else:
                    return False

            while getattr(instance,
                          'OS-EXT-SRV-ATTR:host') != dest_hostname \
                    and retry:
                instance = self.nova.servers.get(instance.id)
                if not getattr(instance, 'OS-EXT-STS:task_state'):
                    LOG.debug("Instance task state: %s is null", instance_id)
                    break
                LOG.debug(
                    'Waiting the migration of {0}  to {1}'.format(
                        instance,
                        getattr(instance,
                                'OS-EXT-SRV-ATTR:host')))
                time.sleep(1)
                retry -= 1

            host_name = getattr(instance, 'OS-EXT-SRV-ATTR:host')
            if host_name != dest_hostname:
                return False

            LOG.debug(
                "Live migration succeeded : "
                "instance %(instance)s is now on host '%(host)s'.",
                {'instance': instance_id, 'host': host_name})

            return True

    def abort_live_migrate(self, instance_id, source, destination, retry=240):
        LOG.debug("Aborting live migration of instance %s", instance_id)
        migration = self.get_running_migration(instance_id)
        if migration:
            migration_id = getattr(migration[0], "id")
            try:
                self.nova.server_migrations.live_migration_abort(
                    server=instance_id, migration=migration_id)
            except exception as e:
                # Note: Does not return from here, as abort request can't be
                # accepted but migration still going on.
                LOG.exception(e)
        else:
            LOG.debug(
                "No running migrations found for instance %s", instance_id)

        while retry:
            instance = self.nova.servers.get(instance_id)
            if (getattr(instance, 'OS-EXT-STS:task_state') is None and
               getattr(instance, 'status') in ['ACTIVE', 'ERROR']):
                break
            time.sleep(2)
            retry -= 1
        instance_host = getattr(instance, 'OS-EXT-SRV-ATTR:host')
        instance_status = getattr(instance, 'status')

        # Abort live migration successful, action is cancelled
        if instance_host == source and instance_status == 'ACTIVE':
            return True
        # Nova Unable to abort live migration, action is succeeded
        elif instance_host == destination and instance_status == 'ACTIVE':
            return False

        else:
            raise Exception("Live migration execution and abort both failed "
                            "for the instance %s" % instance_id)

    def enable_service_nova_compute(self, hostname):
        if float(CONF.nova_client.api_version) < 2.53:
            status = self.nova.services.enable(
                host=hostname, binary='nova-compute').status == 'enabled'
        else:
            service_uuid = self.nova.services.list(host=hostname,
                                                   binary='nova-compute')[0].id
            status = self.nova.services.enable(
                service_uuid=service_uuid).status == 'enabled'

        return status

    def disable_service_nova_compute(self, hostname, reason=None):
        if float(CONF.nova_client.api_version) < 2.53:
            status = self.nova.services.disable_log_reason(
                host=hostname,
                binary='nova-compute',
                reason=reason).status == 'disabled'
        else:
            service_uuid = self.nova.services.list(host=hostname,
                                                   binary='nova-compute')[0].id
            status = self.nova.services.disable_log_reason(
                service_uuid=service_uuid,
                reason=reason).status == 'disabled'

        return status

    def set_host_offline(self, hostname):
        # See API on https://developer.openstack.org/api-ref/compute/
        # especially the PUT request
        # regarding this resource : /v2.1/os-hosts/​{host_name}​
        #
        # The following body should be sent :
        # {
        # "host": {
        # "host": "65c5d5b7e3bd44308e67fc50f362aee6",
        # "maintenance_mode": "off_maintenance",
        # "status": "enabled"
        # }
        # }

        # Voir ici
        # https://github.com/openstack/nova/
        # blob/master/nova/virt/xenapi/host.py
        # set_host_enabled(self, enabled):
        # Sets the compute host's ability to accept new instances.
        # host_maintenance_mode(self, host, mode):
        # Start/Stop host maintenance window.
        # On start, it triggers guest instances evacuation.
        host = self.nova.hosts.get(hostname)

        if not host:
            LOG.debug("host not found: %s", hostname)
            return False
        else:
            host[0].update(
                {"maintenance_mode": "disable", "status": "disable"})
            return True

    def create_image_from_instance(self, instance_id, image_name,
                                   metadata={"reason": "instance_migrate"}):
        """This method creates a new image from a given instance.

        It waits for this image to be in 'active' state before returning.
        It returns the unique UUID of the created image if successful,
        None otherwise.

        :param instance_id: the uniqueid of
            the instance to backup as an image.
        :param image_name: the name of the image to create.
        :param metadata: a dictionary containing the list of
            key-value pairs to associate to the image as metadata.
        """
        LOG.debug(
            "Trying to create an image from instance %s ...", instance_id)

        # Looking for the instance
        instance = self.find_instance(instance_id)

        if not instance:
            LOG.debug("Instance not found: %s", instance_id)
            return None
        else:
            host_name = getattr(instance, 'OS-EXT-SRV-ATTR:host')
            LOG.debug(
                "Instance %(instance)s found on host '%(host)s'.",
                {'instance': instance_id, 'host': host_name})

            # We need to wait for an appropriate status
            # of the instance before we can build an image from it
            if self.wait_for_instance_status(instance, ('ACTIVE', 'SHUTOFF'),
                                             5,
                                             10):
                image_uuid = self.nova.servers.create_image(instance_id,
                                                            image_name,
                                                            metadata)

                image = self.glance.images.get(image_uuid)
                if not image:
                    return None

                # Waiting for the new image to be officially in ACTIVE state
                # in order to make sure it can be used
                status = image.status
                retry = 10
                while status != 'active' and status != 'error' and retry:
                    time.sleep(5)
                    retry -= 1
                    # Retrieve the instance again so the status field updates
                    image = self.glance.images.get(image_uuid)
                    if not image:
                        break
                    status = image.status
                    LOG.debug("Current image status: %s", status)

                if not image:
                    LOG.debug("Image not found: %s", image_uuid)
                else:
                    LOG.debug(
                        "Image %(image)s successfully created for "
                        "instance %(instance)s",
                        {'image': image_uuid, 'instance': instance_id})
                    return image_uuid
        return None

    def delete_instance(self, instance_id):
        """This method deletes a given instance.

        :param instance_id: the unique id of the instance to delete.
        """
        LOG.debug("Trying to remove instance %s ...", instance_id)

        instance = self.find_instance(instance_id)

        if not instance:
            LOG.debug("Instance not found: %s", instance_id)
            return False
        else:
            self.nova.servers.delete(instance_id)
            LOG.debug("Instance %s removed.", instance_id)
            return True

    def stop_instance(self, instance_id):
        """This method stops a given instance.

        :param instance_id: the unique id of the instance to stop.
        """
        LOG.debug("Trying to stop instance %s ...", instance_id)

        instance = self.find_instance(instance_id)

        if not instance:
            LOG.debug("Instance not found: %s", instance_id)
            return False
        elif getattr(instance, 'OS-EXT-STS:vm_state') == "stopped":
            LOG.debug("Instance has been stopped: %s", instance_id)
            return True
        else:
            self.nova.servers.stop(instance_id)

            if self.wait_for_instance_state(instance, "stopped", 8, 10):
                LOG.debug("Instance %s stopped.", instance_id)
                return True
            else:
                return False

    def wait_for_instance_state(self, server, state, retry, sleep):
        """Waits for server to be in a specific state

        The state can be one of the following :
        active, stopped

        :param server: server object.
        :param state: for which state we are waiting for
        :param retry: how many times to retry
        :param sleep: seconds to sleep between the retries
        """
        if not server:
            return False

        while getattr(server, 'OS-EXT-STS:vm_state') != state and retry:
            time.sleep(sleep)
            server = self.nova.servers.get(server)
            retry -= 1
        return getattr(server, 'OS-EXT-STS:vm_state') == state

    def wait_for_instance_status(self, instance, status_list, retry, sleep):
        """Waits for instance to be in a specific status

        The status can be one of the following
        : BUILD, ACTIVE, ERROR, VERIFY_RESIZE, SHUTOFF

        :param instance: instance object.
        :param status_list: tuple containing the list of
            status we are waiting for
        :param retry: how many times to retry
        :param sleep: seconds to sleep between the retries
        """
        if not instance:
            return False

        while instance.status not in status_list and retry:
            LOG.debug("Current instance status: %s", instance.status)
            time.sleep(sleep)
            instance = self.nova.servers.get(instance.id)
            retry -= 1
        LOG.debug("Current instance status: %s", instance.status)
        return instance.status in status_list

    def create_instance(self, node_id, inst_name="test", image_id=None,
                        flavor_name="m1.tiny",
                        sec_group_list=["default"],
                        network_names_list=["demo-net"], keypair_name="mykeys",
                        create_new_floating_ip=True,
                        block_device_mapping_v2=None):
        """This method creates a new instance

        It also creates, if requested, a new floating IP and associates
        it with the new instance
        It returns the unique id of the created instance.
        """
        LOG.debug(
            "Trying to create new instance '%(inst)s' "
            "from image '%(image)s' with flavor '%(flavor)s' ...",
            {'inst': inst_name, 'image': image_id, 'flavor': flavor_name})

        try:
            self.nova.keypairs.findall(name=keypair_name)
        except nvexceptions.NotFound:
            LOG.debug("Key pair '%s' not found ", keypair_name)
            return

        try:
            image = self.glance.images.get(image_id)
        except glexceptions.NotFound:
            LOG.debug("Image '%s' not found ", image_id)
            return

        try:
            flavor = self.nova.flavors.find(name=flavor_name)
        except nvexceptions.NotFound:
            LOG.debug("Flavor '%s' not found ", flavor_name)
            return

        # Make sure all security groups exist
        for sec_group_name in sec_group_list:
            group_id = self.get_security_group_id_from_name(sec_group_name)

            if not group_id:
                LOG.debug("Security group '%s' not found ", sec_group_name)
                return

        net_list = list()

        for network_name in network_names_list:
            nic_id = self.get_network_id_from_name(network_name)

            if not nic_id:
                LOG.debug("Network '%s' not found ", network_name)
                return
            net_obj = {"net-id": nic_id}
            net_list.append(net_obj)

        # get availability zone of destination host
        azone = self.nova.services.list(host=node_id,
                                        binary='nova-compute')[0].zone
        instance = self.nova.servers.create(
            inst_name, image,
            flavor=flavor,
            key_name=keypair_name,
            security_groups=sec_group_list,
            nics=net_list,
            block_device_mapping_v2=block_device_mapping_v2,
            availability_zone="%s:%s" % (azone, node_id))

        # Poll at 5 second intervals, until the status is no longer 'BUILD'
        if instance:
            if self.wait_for_instance_status(instance,
                                             ('ACTIVE', 'ERROR'), 5, 10):
                instance = self.nova.servers.get(instance.id)

                if create_new_floating_ip and instance.status == 'ACTIVE':
                    LOG.debug(
                        "Creating a new floating IP"
                        " for instance '%s'", instance.id)
                    # Creating floating IP for the new instance
                    floating_ip = self.nova.floating_ips.create()

                    instance.add_floating_ip(floating_ip)

                    LOG.debug(
                        "Instance %(instance)s associated to "
                        "Floating IP '%(ip)s'",
                        {'instance': instance.id, 'ip': floating_ip.ip})

        return instance

    def get_security_group_id_from_name(self, group_name="default"):
        """This method returns the security group of the provided group name"""
        security_groups = self.neutron.list_security_groups(name=group_name)

        security_group_id = security_groups['security_groups'][0]['id']

        return security_group_id

    def get_network_id_from_name(self, net_name="private"):
        """This method returns the unique id of the provided network name"""
        networks = self.neutron.list_networks(name=net_name)

        # LOG.debug(networks)
        network_id = networks['networks'][0]['id']

        return network_id

    def get_instance_by_uuid(self, instance_uuid):
        return [instance for instance in
                self.nova.servers.list(search_opts={"all_tenants": True,
                                                    "uuid": instance_uuid})]

    def get_instance_by_name(self, instance_name):
        return [instance for instance in
                self.nova.servers.list(search_opts={"all_tenants": True,
                                                    "name": instance_name})]

    def get_instances_by_node(self, host):
        return [instance for instance in
                self.nova.servers.list(search_opts={"all_tenants": True,
                                                    "host": host},
                                       limit=-1)]

    def get_hostname(self, instance):
        return str(getattr(instance, 'OS-EXT-SRV-ATTR:host'))

    def get_running_migration(self, instance_id):
        return self.nova.server_migrations.list(server=instance_id)

    def swap_volume(self, old_volume, new_volume,
                    retry=120, retry_interval=10):
        """Swap old_volume for new_volume"""
        attachments = old_volume.attachments
        instance_id = attachments[0]['server_id']
        # do volume update
        self.nova.volumes.update_server_volume(
            instance_id, old_volume.id, new_volume.id)
        while getattr(new_volume, 'status') != 'in-use' and retry:
            new_volume = self.cinder.volumes.get(new_volume.id)
            LOG.debug('Waiting volume update to {0}'.format(new_volume))
            time.sleep(retry_interval)
            retry -= 1
            LOG.debug("retry count: %s", retry)
        if getattr(new_volume, 'status') != "in-use":
            LOG.error("Volume update retry timeout or error")
            return False

        host_name = getattr(new_volume, "os-vol-host-attr:host")
        LOG.debug(
            "Volume update succeeded : "
            "Volume %s is now on host '%s'.",
            (new_volume.id, host_name))
        return True

    def _check_nova_api_version(self, client, version):
        api_version = api_versions.APIVersion(version_str=version)
        try:
            api_versions.discover_version(client, api_version)
            return True
        except nvexceptions.UnsupportedVersion as e:
            LOG.exception(e)
            return False
