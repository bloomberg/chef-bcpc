# Copyright 2020, Bloomberg Finance L.P.
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

from oslo_log import log as logging

from cinder import context
from cinder import db
from cinder.scheduler import filters
from cinder.volume import volume_types


LOG = logging.getLogger(__name__)


class AccessFilter(filters.BaseBackendFilter):

    def backend_passes(self, backend_state, filter_properties):
        # get the volume type from the filter properties or return None
        volume_type = filter_properties.get('volume_type', None)

        """
        if the user passed a volume type then this filter has nothing to do
        so just return True with the assumption that the other mechanisms in
        place will determine if this is possible or not
        """
        if volume_type is not None:
            return True

        # get the request context object
        r_context = filter_properties.get('context')

        # we can't do anything without the request context
        if r_context is None:
            LOG.fatal("context not found in filter_properties")
            return False

        # get the project id from the request context
        project_id = None

        if hasattr(r_context, 'project_id'):
            project_id = r_context.project_id

        # we can't do anything without a project id
        if project_id is None:
            LOG.fatal("project id not found in the request context")
            return False

        # we need the admin context to fetch the list of backend types
        # and access ids
        admin_context = context.get_admin_context()

        # get all backend types
        backend_types = volume_types.get_all_types(admin_context)

        # get the type name from the backend state
        backend_type_name = backend_state.pool_name

        # get backend state information
        backend_type_info = backend_types.get(backend_type_name)

        # we can't do anything without the backend type information
        if backend_type_info is None:
            LOG.info(
                "no backend type information found for {}. "
                "skipping".format(backend_type_name))
            return False

        # we're only looking for private backend types
        if backend_type_info['is_public']:
            LOG.info(
                "backend type {} is not private. "
                "skipping".format(backend_type_name))
            return False

        # get the backend type id
        backend_type_id = backend_type_info['id']

        # get list of access ids for current backend type
        backend_type_access = db.volume_type_access_get_all(
            admin_context, backend_type_id)

        # look for project id in list of access ids
        backend_type_found = [access for access in backend_type_access
                              if access.project_id == project_id]

        if len(backend_type_found) > 0:
            LOG.info("{} is a valid backend type".format(backend_type_name))
            return True

        LOG.info(
            "could not find project id {} in the {} backend type. "
            "skipping".format(project_id, backend_type_name))

        return False
