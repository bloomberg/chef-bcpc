# Copyright (C) 2016-2022 Lightbits Labs Ltd.
# Copyright (C) 2020 Intel Corporation
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

import glob
import http.client
import os
import re
import tempfile
import time
import traceback

from oslo_concurrency import lockutils
from oslo_concurrency import processutils as putils
from oslo_log import log as logging

from os_brick import exception
from os_brick.i18n import _
from os_brick.initiator.connectors import base
from os_brick.privileged import lightos as priv_lightos
from os_brick import utils
import subprocess
from netifaces import interfaces, ifaddresses, AF_INET, AF_INET6
from oslo_utils import netutils

DEVICE_SCAN_ATTEMPTS_DEFAULT = 5
DISCOVERY_CLIENT_PORT = 6060
LOG = logging.getLogger(__name__)

synchronized = lockutils.synchronized_with_prefix('os-brick-')
nvmec_pattern = ".*nvme[0-9]+[cp][0-9]+.*"
nvmec_match = re.compile(nvmec_pattern)


class LightOSConnector(base.BaseLinuxConnector):
    """Connector class to attach/detach LightOS volumes using NVMe/TCP."""

    WAIT_DEVICE_TIMEOUT = 60

    def __init__(self,
                 root_helper,
                 driver=None,
                 execute=None,
                 device_scan_attempts=DEVICE_SCAN_ATTEMPTS_DEFAULT,
                 message_queue=None,
                 *args,
                 **kwargs):
        super(LightOSConnector, self).__init__(
            root_helper,
            driver=driver,
            execute=execute,
            device_scan_attempts=device_scan_attempts,
            *args, **kwargs)
        self.message_queue = message_queue
        self.DISCOVERY_DIR_PATH = '/etc/discovery-client/discovery.d/'

    @staticmethod
    def get_ip_addresses():
        """
        Find all IPs for the host machine, return list of IP addresses.
        """
        loop_back_ips=['127.0.0.1','0:0:0:0:0:0:0:1', '::1']
        ips = []
        is_ipv6_enabled = netutils.is_ipv6_enabled()
                          
        ifaces = interfaces()
        for iface in ifaces:
            addresses = ifaddresses(iface)
            
            for address_family in (AF_INET, AF_INET6):
                family_addresses = addresses.get(address_family,[])

                if not family_addresses:
                   continue
                
                for address in family_addresses:
                    ip = address['addr']
                    if ip in loop_back_ips:
                       continue
                                        
                    if is_ipv6_enabled and netutils.is_valid_ipv6(ip):
                       parts = ip.split("%")
                       ip = parts[0]
                       ips.append(ip)

                    elif netutils.is_valid_ipv4(ip):
                         ips.append(ip)
                     
        return ips 
 
    @staticmethod
    def get_connector_properties(root_helper, *args, **kwargs):
        """The LightOS connector properties."""
        props = {}
        lightos_connector = LightOSConnector(root_helper=root_helper,
                                             message_queue=None,
                                             execute=kwargs.get('execute'))
        hostnqn = utils.get_host_nqn()
        found_dsc = lightos_connector.find_dsc()
        host_ips = lightos_connector.get_ip_addresses()
        LOG.info('Current host hostNQN %s and IP(s) are %s ', hostnqn, host_ips)

        if not found_dsc:
            LOG.debug('LIGHTOS: did not find dsc, continuing anyway.')

        if hostnqn:
            LOG.debug("LIGHTOS: finally hostnqn: %s dsc: %s",
                      hostnqn, found_dsc)
            props['nqn'] = hostnqn
            props['found_dsc'] = found_dsc
            props['host_ips'] = host_ips
        else:
            LOG.debug('LIGHTOS: no hostnqn found.')

        return props

    def dsc_file_name(self, uuid):
        return os.path.join(self.DISCOVERY_DIR_PATH, "%s.conf" % uuid)

    def find_dsc(self):
        conn = http.client.HTTPConnection("localhost", DISCOVERY_CLIENT_PORT)
        try:
            conn.request("HEAD", "/metrics")
            resp = conn.getresponse()
            return 'found' if resp.status == http.client.OK else ''
        except Exception as e:
            LOG.debug(f'LIGHTOS: {e}')
            out = ''
        return out

    def dsc_need_connect(self, connection_info):
        return not os.path.isfile(self.dsc_file_name(connection_info['uuid']))

    def dsc_connect_volume(self, connection_info):
        if not self.dsc_need_connect(connection_info):
            return

        subsysnqn = connection_info['subsysnqn']
        uuid = connection_info['uuid']
        hostnqn = utils.get_host_nqn()
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as dscfile:
            dscfile.write('# os_brick connector dsc file for LightOS'
                          ' volume: {}\n'.format(uuid))
            for (ip, node) in connection_info['lightos_nodes'].items():
                transport = node['transport_type']
                host = node['target_portal']
                port = node['target_port']
                dscfile.write('-t {} -a {} -s {} -q {} -n {}\n'.format(
                    transport, host, port, hostnqn, subsysnqn))
            dscfile.flush()
            try:
                dest_name = self.dsc_file_name(uuid)
                priv_lightos.move_dsc_file(dscfile.name, dest_name)
            except Exception:
                LOG.warning(
                    "LIGHTOS: Failed to create dsc file for connection with"
                    f" uuid:{uuid}")
                raise

    def dsc_disconnect_volume(self, connection_info):
        uuid = connection_info['uuid']
        try:
            priv_lightos.delete_dsc_file(self.dsc_file_name(uuid))
        except Exception:
            LOG.warning("LIGHTOS: Failed delete dsc file uuid:{}".format(uuid))
            raise

    def monitor_db(self, lightos_db):
        for connection_info in lightos_db.values():
            self.dsc_connect_volume(connection_info)

    def monitor_message_queue(self, message_queue, lightos_db):
        while not message_queue.empty():
            msg = message_queue.get()
            op, connection = msg
            LOG.debug("LIGHTOS: queue got op: %s, connection: %s",
                      op, connection)
            if op == 'delete':
                LOG.info("LIGHTOS: Removing volume: %s from db",
                         connection['uuid'])
                if connection['uuid'] in lightos_db:
                    del lightos_db[connection['uuid']]
                else:
                    LOG.warning("LIGHTOS: No volume: %s found in db",
                                connection['uuid'])
            elif op == 'add':
                LOG.info("LIGHTOS: Adding volume: %s to db",
                         connection['uuid'])
                lightos_db[connection['uuid']] = connection

    def lightos_monitor(self, lightos_db, message_queue):
        '''Bookkeeping lightos connections.

        This is useful when the connector is comming up to a running node with
        connected volumes already exists.
        This is used in the Nova driver to restore connections after reboot
        '''
        first_time = True
        while True:
            self.monitor_db(lightos_db)
            # give us some time before trying to access the MQ
            # for the first time
            if first_time:
                time.sleep(5)
                first_time = False
            else:
                time.sleep(1)

            self.monitor_message_queue(message_queue, lightos_db)

    # This is part of our abstract interface
    def get_search_path(self):
        return '/dev'

    # This is part of our abstract interface
    def get_volume_paths(self, connection_properties):
        path = connection_properties['device_path']
        return [path]

    def _check_device_exists_using_dev_lnk(self, uuid):
        lnk_path = f"/dev/disk/by-id/nvme-uuid.{uuid}"
        if os.path.exists(lnk_path):
            devname = os.path.realpath(lnk_path)
            if devname.startswith("/dev/nvme"):
                LOG.info("LIGHTOS: devpath %s detected for uuid %s",
                         devname, uuid)
                return devname
        return None

    def _check_device_exists_reading_block_class(self, uuid):
        file_path = "/sys/class/block/*/wwid"
        wwid = "uuid." + uuid
        for match_path in glob.glob(file_path):
            try:
                with open(match_path, "r") as f:
                    match_wwid = f.readline()
            except Exception:
                LOG.warning("LIGHTOS: Failed to read file %s",
                            match_path)
                continue

            if wwid != match_wwid.strip():
                continue

            # skip slave nvme devices, for example: nvme0c0n1
            if nvmec_match.match(match_path.split("/")[-2]):
                continue

            LOG.info("LIGHTOS: matching uuid %s was found"
                     " for device path %s", uuid, match_path)
            return os.path.join("/dev", match_path.split("/")[-2])
        return None

    @utils.trace
    def _get_device_by_uuid(self, uuid):
        endtime = time.time() + self.WAIT_DEVICE_TIMEOUT
        while time.time() < endtime:
            try:
                device = self._check_device_exists_using_dev_lnk(uuid)
                if device:
                    return device
            except Exception as e:
                LOG.debug(f'LIGHTOS: {e}')
            device = self._check_device_exists_reading_block_class(uuid)
            if device:
                return device

            time.sleep(1)
        return None

    def _get_size_by_uuid(self, uuid):
        devpath = self._get_device_by_uuid(uuid)
        devname = devpath.split("/")[-1]
        try:
            size_path_name = os.path.join("/sys/class/block/", devname, "size")
            with open(size_path_name, "r") as f:
                size_blks = f.read().strip()
            bytesize = int(size_blks) * 512
            return bytesize
        except Exception:
            LOG.warning("LIGHTOS: Could not find the size at for"
                        " uuid %s in %s", uuid, devpath)
            return None

    @utils.trace
    @synchronized('volume_op')
    def connect_volume(self, connection_properties):
        """Discover and attach the volume.

        :param connection_properties: The dictionary that describes all
                                      of the target volume attributes.
               connection_properties must include:
               nqn - NVMe subsystem name to the volume to be connected
               target_port - NVMe target port that hosts the nqn sybsystem
               target_portal - NVMe target ip that hosts the nqn sybsystem
        :type connection_properties: dict
        :returns: dict
        """
        device_info = {'type': 'block'}
        uuid = connection_properties['uuid']
        LOG.info("LIGHTOS: connect_volume called for volume %s, connection"
                 " properties: %s",
                 uuid, connection_properties)
        self.dsc_connect_volume(connection_properties)

        device_path = self._get_device_by_uuid(uuid)
        if not device_path:
            msg = _("Device with uuid %s did not show up" % uuid)
            priv_lightos.delete_dsc_file(self.dsc_file_name(uuid))
            raise exception.BrickException(message=msg)

        device_info['path'] = device_path

        # bookkeeping lightos connections - add connection
        if self.message_queue:
            self.message_queue.put(('add', connection_properties))

        return device_info

    @utils.trace
    @synchronized('volume_op')
    def disconnect_volume(self, connection_properties, device_info,
                          force=False, ignore_errors=False):
        """Disconnect a volume from the local host.

        The connection_properties are the same as from connect_volume.
        The device_info is returned from connect_volume.
        :param connection_properties: The dictionary that describes all
                                      of the target volume attributes.
        :type connection_properties: dict
        :param device_info: historical difference, but same as connection_props
        :type device_info: dict
        :param force: Whether to forcefully disconnect even if flush fails.
        :type force: bool
        :param ignore_errors: When force is True, this will decide whether to
                              ignore errors or raise an exception once finished
                              the operation.  Default is False.
        :type ignore_errors: bool
        """
        # bookkeeping lightos connections - delete connection
        if self.message_queue:
            self.message_queue.put(('delete', connection_properties))
        uuid = connection_properties['uuid']
        LOG.debug('LIGHTOS: disconnect_volume called for volume %s', uuid)
        device_path = self._get_device_by_uuid(uuid)
        exc = exception.ExceptionChainer()
        try:
            if device_path:
                self._linuxscsi.flush_device_io(device_path)
        except putils.ProcessExecutionError as e:
            exc.add_exception(type(e), e, traceback.format_exc())
            if not (force or ignore_errors):
                raise
        try:
            self.dsc_disconnect_volume(connection_properties)
        except Exception as e:
            exc.add_exception(type(e), e, traceback.format_exc())
        if exc:
            if not ignore_errors:
                raise exc

    @utils.trace
    @synchronized('volume_op')
    def extend_volume(self, connection_properties):
        uuid = connection_properties['uuid']
        new_size = self._get_size_by_uuid(uuid)
        return new_size
