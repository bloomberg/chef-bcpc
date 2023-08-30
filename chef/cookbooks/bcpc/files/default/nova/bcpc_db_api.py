# Copyright (c) 2011 X.commerce, a business unit of eBay Inc.
# Copyright 2010 United States Government as represented by the
# Administrator of the National Aeronautics and Space Administration.
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

from oslo_db import api as oslo_db_api
from nova.db.main.api import pick_context_manager_writer
from nova.db.main.api import _instance_system_metadata_get_query
from nova.db.utils import require_context


@require_context
@oslo_db_api.wrap_db_retry(max_retries=5, retry_on_deadlock=True)
@pick_context_manager_writer
def instance_system_metadata_delete(context, instance_uuid, key):
    """Delete the given metadata item."""
    _instance_system_metadata_get_query(context, instance_uuid).\
        filter_by(key=key).\
        delete()
