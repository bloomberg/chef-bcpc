#!/usr/bin/env python
#
# nova-ephemeral - Allows you to distinguish between ephemeral storage on the local machine where the drives
# may be setup using RAID 0, 1, 5... or LVM or both. If --persistent is passed then the metadata is set for the existing
# along with the persistent-compute-storage aggregate. The persistent storage is backed by RBD volumes. The
# ephemeral storage should be SSD with JBOD architecture which means it's ephemeral and if one drive fails the
# volume fails.  Use RAID 5 if you want more resiliency as a foundation for LVM.
#
# By passing in --hosts-ephemeral you can pass a list of host names that you would like to allocate to ephemeral
# storage. The --hosts-persistent option does the same for persistent storage. If no --hosts-* are passed then the
# hypervisor list is obtained and ephemeral and persistent storage both are allocated for the hosts.

import os
import sys

from oslo_config import cfg
from oslo_log import log
from oslo_log import _options
from keystoneclient.auth.identity import v2
from keystoneclient import session
from novaclient import client
from novaclient import exceptions

common_opts = [
    cfg.BoolOpt('ephemeral', default=False,
                help='Creates ephemeral storage options.'),
    cfg.BoolOpt('persistent', default=False,
                help='Creates persistent storage options.'),
    cfg.BoolOpt('hosts-all', default=False,
                help='If true (present) then all hypervisors will be added to host list if host list is empty.'),
    cfg.StrOpt('availability-zone', default='-',
               help='Availability Zone.'),
    cfg.StrOpt('aggregate-name-ephemeral', default='ephemeral-compute-storage',
               help='Ephemeral host aggregate name.'),
    cfg.StrOpt('aggregate-name-persistent', default='persistent-compute-storage',
               help='Persistent host aggregate name.'),
    cfg.ListOpt('hosts-ephemeral', default=None,
                help='Provide a list of host names that support ephemeral storage.'),
    cfg.ListOpt('hosts-persistent', default=None,
                help='Provide a list of host names that support persistent storage.'),
    cfg.StrOpt('ephemeral-flavor-name', default='e1',
               help='Ephemeral flavor name.'),
    cfg.StrOpt('persistent-flavor-name', default='m1',
               help='persistent flavor name.'),
    cfg.StrOpt('os-auth-url', default=os.environ.get('OS_AUTH_URL'),
               help='OS_AUTH_URL value.'),
    cfg.StrOpt('os-region-name', default=os.environ.get('OS_REGION_NAME'),
               help='OS_REGION_NAME value.'),
    cfg.StrOpt('os-tenant-name', default=os.environ.get('OS_TENANT_NAME'),
               help='OS_TENANT_NAME value.'),
    cfg.StrOpt('os-username', default=os.environ.get('OS_USERNAME'),
               help='OS_USERNAME value.'),
    cfg.StrOpt('os-password', default=os.environ.get('OS_PASSWORD'),
               help='OS_PASSWORD value.'),
    cfg.StrOpt('os-cacert', default=os.environ.get('OS_CACERT'),
               help='OS_CACERT value.'),
    cfg.StrOpt('os-compute-api-version', default=os.environ.get('OS_COMPUTE_API_VERSION'),
               help='OS_COMPUTE_API_VERSION value.')
]

CONF = cfg.CONF
CONF.register_cli_opts(common_opts)

_DEFAULT_LOG_LEVELS = ['nova-ephemeral=INFO']

_DEFAULT_LOGGING_CONTEXT_FORMAT = ('%(color)s %(asctime)s.%(msecs)03d %(process)d '
                                   '%(levelname)s %(name)s [%(request_id)s '
                                   '%(user_identity)s] %(instance)s'
                                   '%(message)s')

OS_AUTH_URL = None
OS_REGION_NAME = None
OS_TENANT_NAME = None
OS_USERNAME = None
OS_PASSWORD = None
OS_CACERT = None
OS_COMPUTE_API_VERSION = None

def get_client():
    auth = v2.Password(auth_url=OS_AUTH_URL,
                       username=OS_USERNAME,
                       password=OS_PASSWORD,
                       tenant_name=OS_TENANT_NAME)
    sess = session.Session(auth=auth)
    nova = client.Client(OS_COMPUTE_API_VERSION, session=sess)
    return nova

# av_zone must be at least 1 character in size.
def create(nova, aggregate_type, flavor_name, aggregate_name=None, av_zone='-', verbose=False, hosts=None, hosts_all=False):
    if not nova:
        return None

    if not hosts and hosts_all is False:
        LOG.error('Hosts list is empty and option --hosts-all=False (default value).')
        return None

    if verbose:
        LOG.info('Starting create function.')
    ret_value = False
    id = None

    # Step 1: Gather list with IDs and check for existence.

    aggregate_name_list=[]
    aggregate_list = nova.aggregates.list()
    for agg in aggregate_list:
        aggregate_name_list.append(agg.name)

    agg = None

    if aggregate_name not in aggregate_name_list:
        try:
            agg = nova.aggregates.create(aggregate_name, av_zone)
        except exceptions.Conflict, e:
            # Already exists but still passed earlier check
            LOG.warn('Aggregate %s already exists.' % aggregate_name)
    else:
        for agg in aggregate_list:  # Find agg by name
            if agg.name == aggregate_name:
                break

    if not hosts:
        # Build host list from hypervisor list
        host_list = nova.hypervisors.list()
        hosts=[]
        for host in host_list:
            hosts.append(host.hypervisor_hostname)  # May want to remove domain portion of name??
            if verbose:
                LOG.info('hosts value not passed. Building hosts list: %s' % host)

    new_hosts=[]
    # Attempt to add using hosts list.
    for host in hosts:
        try:
            tmp = nova.aggregates.add_host(agg, host)
        except exceptions.Conflict, e:
            LOG.warn('Host aggregate %s for %s aggregate already exists (1).' % (host, aggregate_name))
        except exceptions.NotFound, e:
            # Host name not found which means you need to look at compute_nodes in the nova db and find out why
            # they have a fqdn but the service list only has the host name portion which is checked against.
            new_hosts.append(host)
            LOG.warn('Host %s not found (hypervisor list is different from service host list).' % host)

    if new_hosts:
        hosts=[]
        service_list = nova.services.list()
        for service in service_list:
            if service.binary == 'nova-compute':
                # Find host in list
                for host in new_hosts:
                    if host.find(service.host+'.') >= 0:
                        hosts.append(service.host)
                        break
        # Attempt one more time with correct host name or fail
        for host in hosts:
            try:
                tmp = nova.aggregates.add_host(agg, host)
            except exceptions.Conflict, e:
                LOG.warn('Host Aggregate %s for %s aggregate already exists (2).' % (host, aggregate_name))

    # Add the aggregate metadata. If exists then just keep going else fail.
    try:
        meta = {}
        meta['%scomputestorage' % aggregate_type] = 'true'
        agg.set_metadata(meta)
    except exceptions.Conflict, e:
        LOG.warn('Aggregate %s already has metadata.' % aggregate_name)

    # Get the flavors
    flavor_list=[]
    flv_list = nova.flavors.list()
    for flavor in flv_list:
        if flavor.ephemeral == 0:  # Only want the ones that do not have an ephemeral drive
            flavor_list.append(flavor)

    if aggregate_type == 'ephemeral':  # Could change the logic to check for metadata too
        for flavor in flavor_list:  # Update the flavors to support ephemeral
            try:
                index = flavor.name.find('.')
                flavor.name = '%s%s' % (flavor_name, flavor.name[index:])
                flavor.id = 'e%s' % flavor.id
                flv = None
                try:
                    flv = nova.flavors.create(flavor.name, flavor.ram, flavor.vcpus,
                                              flavor.disk, flavor.id, ephemeral=flavor.disk,
                                              is_public=flavor.is_public)
                except exceptions.Conflict, e:
                    LOG.warn('Flavor %s already exists.' % flavor.name)
                    flv = get_flavor(name=flavor.name)
                meta = {'%scomputestorage' % aggregate_type: 'true'}
                meta = flv.set_keys(meta)
            except exceptions.Conflict, e:
                LOG.warn('Metadata for flavor %s already exists.' % flavor.name)
    else:  # Main thing here is to update the metadata key
        for flavor in flavor_list:
            try:
                flavor.set_keys({'%scomputestorage' % aggregate_type: 'true'})
            except exceptions.Conflict, e:
                LOG.warn('Metadata for flavor %s already exists.' % flavor.name)

    ret_value = True
    if verbose:
        LOG.info('Ending create function.')

    return ret_value


def get_flavor(name=None, id=None):
    if not name and not id:
        return None

    try:
        flv_list = nova.flavors.list()  # Make it more optimized later
        for flavor in flv_list:
            if name:
                tmp_name = flavor.name
                if tmp_name.lower() == name.lower():
                    return flavor
            if id:
                if flavor.id == id:
                    return flavor
    except BaseException, e:
        LOG.error(e.message)
    return None


if __name__ == "__main__":
    ret_value = 1
    # Creates a log file in the local directory so that you can see the data passed and know what exactly happened.
    cfg.set_defaults(_options.logging_cli_opts, log_file='nova-ephemeral.log')
    log.set_defaults(_DEFAULT_LOGGING_CONTEXT_FORMAT, _DEFAULT_LOG_LEVELS)
    log.register_options(CONF)
    log.setup(CONF, 'nova-ephemeral', '0.0.1')

    LOG = log.getLogger('nova-ephemeral')

    CONF(args=sys.argv[1:], version='0.0.1', project='nova-ephemeral', validate_default_values=True)

    OS_AUTH_URL = CONF.os_auth_url
    OS_REGION_NAME = CONF.os_region_name
    OS_TENANT_NAME = CONF.os_tenant_name
    OS_USERNAME = CONF.os_username
    OS_PASSWORD = CONF.os_password
    OS_CACERT = CONF.os_cacert
    OS_COMPUTE_API_VERSION = CONF.os_compute_api_version

    nova = get_client()

    if CONF.verbose:
        LOG.info('CLI Values:')
        LOG.info('%s' % CONF.items())

    try:
        ret = False
        if CONF.ephemeral:
            ret = create(nova, 'ephemeral', CONF.ephemeral_flavor_name,
                         aggregate_name=CONF.aggregate_name_ephemeral,
                         av_zone=CONF.availability_zone, verbose=CONF.verbose, hosts=CONF.hosts_ephemeral,
                         hosts_all=CONF.hosts_all)
        if CONF.persistent:
            ret = create(nova, 'persistent', CONF.persistent_flavor_name,
                         aggregate_name=CONF.aggregate_name_persistent,
                         av_zone=CONF.availability_zone, verbose=CONF.verbose, hosts=CONF.hosts_persistent,
                         hosts_all=CONF.hosts_all)
        if ret:
            ret_value = 0
    except BaseException, e:
        LOG.error(e.message)

    exit(ret_value)
