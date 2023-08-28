# Copyright 2011 OpenStack Foundation
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


from webob import exc

from nova.api.openstack import common
from nova.api.openstack.compute.schemas import server_system_metadata
from nova.api.openstack import wsgi
from nova.api import validation
from nova.compute import api as compute
from nova import exception
from nova.i18n import _
from nova.policies import server_system_metadata as ssm_policies


class ServerSystemMetadataController(wsgi.Controller):
    """The server system metadata API controller for the OpenStack API."""

    def __init__(self):
        super(ServerSystemMetadataController, self).__init__()
        self.compute_api = compute.API()

    def _get_system_metadata(self, context, server):
        try:
            sys_meta = self.compute_api.get_instance_system_metadata(context,
                                                                     server)
        except exception.InstanceNotFound:
            msg = _('Server does not exist')
            raise exc.HTTPNotFound(explanation=msg)
        sys_meta_dict = {}
        for key, value in sys_meta.items():
            sys_meta_dict[key] = value
        return sys_meta_dict

    @wsgi.expected_errors(404)
    def index(self, req, server_id):
        """Returns the list of system metadata for a given instance."""
        context = req.environ['nova.context']
        server = common.get_instance(self.compute_api, context, server_id)
        context.can(ssm_policies.POLICY_ROOT % 'index',
                    target={'project_id': server.project_id})
        return {'system_metadata': self._get_system_metadata(context, server)}

    @wsgi.expected_errors((403, 404, 409))
    @validation.schema(server_system_metadata.create)
    def create(self, req, server_id, body):
        sys_metadata = body['system_metadata']
        context = req.environ['nova.context']
        server = common.get_instance(self.compute_api, context, server_id)
        context.can(ssm_policies.POLICY_ROOT % 'create',
                    target={'project_id': server.project_id})
        new_sys_metadata = self._update_instance_system_metadata(context,
                                                                 server,
                                                                 sys_metadata,
                                                                 delete=False)

        return {'system_metadata': new_sys_metadata}

    @wsgi.expected_errors((400, 403, 404, 409))
    @validation.schema(server_system_metadata.update)
    def update(self, req, server_id, id, body):
        context = req.environ['nova.context']
        server = common.get_instance(self.compute_api, context, server_id)
        context.can(ssm_policies.POLICY_ROOT % 'update',
                    target={'project_id': server.project_id})
        sys_meta_item = body['system_metadata']
        if id not in sys_meta_item:
            expl = _('Request body and URI mismatch')
            raise exc.HTTPBadRequest(explanation=expl)

        self._update_instance_system_metadata(context,
                                              server,
                                              sys_meta_item,
                                              delete=False)

        return {'system_metadata': sys_meta_item}

    @wsgi.expected_errors((403, 404, 409))
    @validation.schema(server_system_metadata.update_all)
    def update_all(self, req, server_id, body):
        context = req.environ['nova.context']
        server = common.get_instance(self.compute_api, context, server_id)
        context.can(ssm_policies.POLICY_ROOT % 'update_all',
                    target={'project_id': server.project_id})
        sys_metadata = body['system_metadata']
        new_sys_metadata = self._update_instance_system_metadata(context,
                                                                 server,
                                                                 sys_metadata,
                                                                 delete=True)

        return {'system_metadata': new_sys_metadata}

    def _update_instance_system_metadata(self,
                                         context,
                                         server,
                                         sys_meta,
                                         delete=False):
        try:
            return self.compute_api.update_instance_system_metadata(context,
                                                                    server,
                                                                    sys_meta,
                                                                    delete)
        except exception.OverQuota as error:
            raise exc.HTTPForbidden(explanation=error.format_message())
        except exception.InstanceIsLocked as e:
            raise exc.HTTPConflict(explanation=e.format_message())
        except exception.InstanceInvalidState as state_error:
            msg = 'update system metadata'
            common.raise_http_conflict_for_instance_invalid_state(state_error,
                                                                  msg,
                                                                  server.uuid)

    @wsgi.expected_errors(404)
    def show(self, req, server_id, id):
        """Return a single system metadata item."""
        context = req.environ['nova.context']
        server = common.get_instance(self.compute_api, context, server_id)
        context.can(ssm_policies.POLICY_ROOT % 'show',
                    target={'project_id': server.project_id})
        data = self._get_system_metadata(context, server)

        try:
            return {'system_metadata': {id: data[id]}}
        except KeyError:
            msg = _("System metadata item was not found")
            raise exc.HTTPNotFound(explanation=msg)

    @wsgi.expected_errors((404, 409))
    @wsgi.response(204)
    def delete(self, req, server_id, id):
        """Deletes an existing system metadata."""
        context = req.environ['nova.context']
        server = common.get_instance(self.compute_api, context, server_id)
        context.can(ssm_policies.POLICY_ROOT % 'delete',
                    target={'project_id': server.project_id})
        sys_metadata = self._get_system_metadata(context, server)

        if id not in sys_metadata:
            msg = _("Metadata item was not found")
            raise exc.HTTPNotFound(explanation=msg)

        try:
            self.compute_api.delete_instance_system_metadata(context,
                                                             server,
                                                             id)
        except exception.InstanceIsLocked as e:
            raise exc.HTTPConflict(explanation=e.format_message())
        except exception.InstanceInvalidState as state_error:
            msg = 'delete system metadata'
            common.raise_http_conflict_for_instance_invalid_state(state_error,
                                                                  msg,
                                                                  server_id)
