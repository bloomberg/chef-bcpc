
# Cookbook Name:: bcpc-zabbix
# Provider:: zbxnotify
#
# Copyright 2015, Bloomberg Finance L.P.
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

def whyrun_supported?
  true
end

action :create do
  params = {
    :user     => get_config('zabbix-admin-user'),
    :password => get_config('zabbix-admin-password')
  }
  auth = zbx_api(nil, 'user.login', params)
  raise 'Zabbix authentication failed' if auth.nil?

  # Checks for existence of script mediatype
  params = {
    :filter => {
      :type        => 1,
      :description => @new_resource.name
    },
    :limit  => 1
  }
  mt = zbx_api(auth, 'mediatype.get', params)
  if mt.length == 0
    params = {
      :type        => 1,
      :description => @new_resource.name,
      :exec_path   => @new_resource.script_filename
    }
    mt = zbx_api(auth, 'mediatype.create', params)
    mediatypeid = mt['mediatypeids'][0]
    Chef::Log.info("Mediatype #{@new_resource.name} created: #{mediatypeid}")
  else
    mediatypeid = mt[0]['mediatypeid']
    Chef::Log.info("Mediatype #{@new_resource.name} already exists: #{mediatypeid}")
  end

  # Obtain admin UID
  params = {
    :filter => {
      :alias => 'admin'
    }
  }
  admin_user = zbx_api(auth, 'user.get', params)
  zbx_admin_uid = admin_user[0]['userid'] if admin_user.length == 1
  raise 'Unable to obtain Zabbix admin UID' if zbx_admin_uid.nil?

  # Check for user mediatype assocation
  params = {
    :userids      => zbx_admin_uid,
    :mediatypeids => mediatypeid
  }
  if zbx_api(auth, 'user.get', params).length == 0
    # Associate mediatype with admin user if not already done
    params = {
      :users  => [{:userid => zbx_admin_uid.to_i}],
      :medias => {
        :mediatypeid => mediatypeid,
        :sendto      => @new_resource.sendto,
        :active      => 0,
        :severity    => @new_resource.severity,
        :period      => @new_resource.period
      }
    }
    if zbx_api(auth, 'user.addmedia', params).nil?
      raise "Unable to associate #{@new_resource.name} mediatype with userid #{zbx_admin_uid}"
    end
  end

  # A simplistic check for action existence. This accommodates further user
  # customization that this provider does not currently provides.
  if zbx_api(auth, 'action.exists', {:name => @new_resource.name}) == false
    # Setup trigger action conditions and operations
    # https://www.zabbix.com/documentation/2.4/manual/api/reference/action/object
    filter = {
      :evaltype => 0,
      :conditions => [
        {
           # condition: Host is not in maintenance status
          :conditiontype => 16,
          :operator      => 7,
          :value         => ''
        },
        {
          # condition: Trigger value = PROBLEM
          :conditiontype => 5,
          :operator      => 0,
          # https://www.zabbix.com/documentation/2.4/manual/api/reference/trigger/object#trigger
          :value         => 1
        }
      ]
    }

    operations = [
      {
        :operationtype => 0,
        :esc_period    => 0,
        :esc_step_from => 1,
        :esc_step_to   => 1,
        :opmessage_usr => [{:userid => zbx_admin_uid}],
        :opmessage     => {
          :default_msg => 1,
          :mediatypeid => mediatypeid
        },
        :opconditions  => [
          {
            :conditiontype => 14,
            :value         => 0
          }
        ]
      }
    ]

    params = {
      :name          => @new_resource.name,
      :esc_period    => @new_resource.esc_period,
      :eventsource   => @new_resource.eventsource,
      :def_longdata  => @new_resource.def_longdata,
      :def_shortdata => @new_resource.def_shortdata,
      :recovery_msg  => @new_resource.recovery_msg,
      :r_longdata    => @new_resource.r_longdata,
      :r_shortdata   => @new_resource.r_shortdata,
      :filter        => filter,
      :operations    => operations
    }
    action = zbx_api(auth, 'action.create', params)
    Chef::Log.info("Action created: #{action}")
  end

end
