# Administrator of the National Aeronautics and Space Administration.
# Copyright 2011 Piston Cloud Computing, Inc.
# Copyright 2012-2013 Red Hat, Inc.
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

from nova.compute import api as compute
from nova.compute import vm_states
from nova.db.main import api as main_db_api


class API(compute.API):
    def __init__(self, image_api=None, network_api=None, volume_api=None):
        super(API, self).__init__(image_api=image_api,
                                  network_api=network_api,
                                  volume_api=volume_api)

    def get_instance_system_metadata(self, context, instance):
        """Get all system metadata associated with an instance."""
        return main_db_api.instance_system_metadata_get(context, instance.uuid)

    @compute.check_instance_lock
    @compute.check_instance_state(vm_state=[vm_states.STOPPED],
                                  task_state=None)
    def delete_instance_system_metadata(self, context, instance, key):
        """Delete the given system metadata item from an instance."""
        instance.delete_system_metadata_key(key)

    @compute.check_instance_lock
    @compute.check_instance_state(vm_state=[vm_states.STOPPED],
                                  task_state=None)
    def update_instance_if_stopped(self, context, instance, updates):
        """Updates a single Instance object with some updates dict if the
        instance is currently stopped.

        Returns the updated instance.
        """
        return self.update_instance(context, instance, updates)

    @compute.check_instance_lock
    @compute.check_instance_state(vm_state=[vm_states.STOPPED],
                                  task_state=None)
    def update_instance_system_metadata(self, context, instance,
                                        sys_metadata, delete=False):
        """Updates or creates instance system metadata.
        
        If delete is True, system metadata items that are not specified in the
        `sys_metadata` argument will be deleted.
        
        """
        if delete:
            _sys_metadata = sys_metadata
        else:
            _sys_metadata = dict(instance.system_metadata)
            _sys_metadata.update(sys_metadata)
        
        instance.system_metadata = _sys_metadata
        instance.save()
    
        return _sys_metadata
