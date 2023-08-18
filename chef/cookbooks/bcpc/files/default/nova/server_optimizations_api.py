# Copyright 2023, Bloomberg L.P.
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

from webob import exc

from nova.api.openstack import common
from nova.api.openstack.compute import helpers
from nova.api.openstack.compute.schemas import server_optimizations
from nova.api.openstack import wsgi
from nova.api import validation
from nova.compute import api as compute
from nova import exception
from nova.i18n import _
from nova.policies import server_optimizations as so_policies


class ServerOptimizationsController(wsgi.Controller):
    """The server optimization API controller for the OpenStack API."""

    def __init__(self):
        super(ServerOptimizationsController, self).__init__()
        self.compute_api = compute.API()

    @wsgi.expected_errors(404)
    def show(self, req, server_id, id):
        """Returns server details by server id."""
        context = req.environ['nova.context']
        server = common.get_instance(self.compute_api, context, server_id)
        context.can(so_policies.POLICY_ROOT % 'show',
                    target={'project_id': server.project_id})

        opt_value = getattr(server, id) if server.obj_attr_is_set(id) else None
        return {'optimizations': {id: opt_value}}

    @wsgi.expected_errors((400, 403, 404, 409))
    @validation.schema(server_optimizations.update)
    def update(self, req, server_id, id, body):
        """Update server then pass on to version-specific controller."""

        context = req.environ['nova.context']
        update_dict = {}
        server = common.get_instance(self.compute_api, context, server_id)
        context.can(so_policies.POLICY_ROOT % 'update',
                    target={'user_id': server.user_id,
                            'project_id': server.project_id})

        optimizations = body['optimizations']
        if id not in optimizations:
            expl = _('Request body and URI mismatch')
            raise exc.HTTPBadRequest(explanation=expl)
        if 'os_type' in optimizations:
            update_dict['os_type'] = optimizations['os_type']

        helpers.translate_attributes(helpers.UPDATE,
                                     optimizations,
                                     update_dict)
        try:
            server = self.compute_api.update_instance(
                context, server, update_dict)
            return {'optimizations': {id: getattr(server, id)}}
        except exception.InstanceNotFound:
            msg = _("Instance could not be found")
            raise exc.HTTPNotFound(explanation=msg)
