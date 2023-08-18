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


import functools

from nova.api.openstack.compute import routes
from nova.api.openstack.compute import server_optimizations
from nova.api.openstack.compute import server_system_metadata

server_system_metadata_controller = functools.partial(
    routes._create_controller,
    server_system_metadata.ServerSystemMetadataController, [])

server_optimizations_controller = functools.partial(
    routes._create_controller,
    server_optimizations.ServerOptimizationsController, [])


class BCPCAPIRouterV21(routes.APIRouterV21):

    """Routes requests on the OpenStack API to the appropriate controller

    and method. The URL mapping based on the plain list `ROUTE_LIST` is built

    at here.
    """

    def __init__(self):
        bcpc_custom_route = (
            ('/servers/{server_id}/system-metadata', {
                'GET': [server_system_metadata_controller, 'index'],
                'POST': [server_system_metadata_controller, 'create'],
                'PUT': [server_system_metadata_controller, 'update_all'],
            }),
            ('/servers/{server_id}/system-metadata/{id}', {
                'GET': [server_system_metadata_controller, 'show'],
                'PUT': [server_system_metadata_controller, 'update'],
                'DELETE': [server_system_metadata_controller, 'delete'],
            }),
            ('/servers/{server_id}/optimizations/{id}', {
                'GET': [server_optimizations_controller, 'show'],
                'PUT': [server_optimizations_controller, 'update'],
            }),

        )
        super(BCPCAPIRouterV21, self).__init__(custom_routes=bcpc_custom_route)
