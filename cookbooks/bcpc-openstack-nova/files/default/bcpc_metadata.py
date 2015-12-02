"""
A metadata service to provide tenancy information to a VM. 

example usage (from within the VM):
$  curl http://169.254.169.254/openstack/latest/vendor_data.json
{"users": [{"username": "admin", "uuid": "e96554f436384387868a61a5bfc55abf"}, {"username": "tester", "uuid": "f6ca026c1570449598060901aa813fea"}, {"username": "caius", "uuid": "64e0b81d4b21437b92b38daa5276b188"}], "name": "AdminTenant", "uuid": "1e093084ea294ff6b261184ec7818459"}

Note, the metadata service caches data for 15s (default) so the actual load this places on the system is pretty minimal. 

"""

import errno
import time

from oslo.config import cfg

from nova.api.metadata import base
from nova.openstack.common.gettextutils import _
from nova.openstack.common import jsonutils
from nova.openstack.common import log as logging
from keystoneclient.v2_0 import client as kclient

CONF = cfg.CONF
LOG = logging.getLogger(__name__)

class BcpcMetadata(base.VendorDataDriver):
    def __init__(self, *args, **kwargs):
        super(BcpcMetadata, self).__init__(*args, **kwargs)        
        instance = kwargs["instance"]
        self._instance_uuid = instance.uuid
        try:
            self._project_uuid = instance.project_id
        except:
            self._project_uuid = ""
        self._kclient = kclient.Client(username=CONF.keystone_authtoken.admin_user, 
                                       password=CONF.keystone_authtoken.admin_password,
                                       tenant_name=CONF.keystone_authtoken.admin_tenant_name, 
                                       auth_url=CONF.keystone_authtoken.auth_uri,
                                       cacert = CONF.keystone_authtoken.cafile)
        self._data = { 'users' : []}

    def get(self):
        tenant = self._kclient.tenants.get(self._project_uuid)
        for user in tenant.list_users():
            self._data['users'].append(
                { 'uuid' : user.id,
                  'username' : user.username } )
        self._data['uuid'] = tenant.id
        self._data['name'] = tenant.name
        self._lastupdate = time.time()
        return self._data


                 
