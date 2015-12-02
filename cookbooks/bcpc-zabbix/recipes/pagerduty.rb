#
# Cookbook Name:: bcpc-zabbix
# Recipe:: pagerduty
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
#

if node['bcpc']['monitoring']['pagerduty']['enabled'] then

    # Pagerduty integration script
    cookbook_file '/usr/lib/zabbix/alertscripts/pagerduty.py' do
        source 'pagerduty-zabbix-proxy.py'
        cookbook 'bcpc-binary-files'
        owner 'root'
        mode 00755
        not_if "shasum /usr/lib/zabbix/alertscripts/pagerduty.py | grep -q '^8a55e3ad8139054366d3feb2b7e6f4f0d712285a'"
    end

    # Patch for pd-zabbix-proxy.py to accept configurable proxy server
    bcpc_foundation_patch '/usr/lib/zabbix/alertscripts/pagerduty.py' do
        patch_file           'pagerduty-zabbix-configurable-proxy.patch'
        patch_root_dir       '/usr/lib/zabbix'
        shasums_before_apply 'pagerduty-zabbix-configurable-proxy.patch.BEFORE.SHASUMS'
        shasums_after_apply  'pagerduty-zabbix-configurable-proxy.patch.AFTER.SHASUMS'
    end

    template '/etc/pagerduty.conf' do
        source 'pagerduty.conf.erb'
        owner 'root'
        group 'root'
        mode 00644
        variables(
            :proxy_server_url => node['bcpc']['proxy_server_url']
        )
    end

    bcpc_zabbix_zbxnotify 'pagerduty' do
        name 'Pagerduty'
        script_filename 'pagerduty.py'
        sendto node['bcpc']['monitoring']['pagerduty']['key']
        def_longdata "name:{TRIGGER.NAME}\r\nid:{TRIGGER.ID}\r\nstatus:{TRIGGER.STATUS}\r\nhostname:{HOSTNAME}\r\nip:{IPADDRESS}\r\nvalue:{TRIGGER.VALUE}\r\nevent_id:{EVENT.ID}\r\nseverity: {TRIGGER.SEVERITY}\r\n"
        def_shortdata 'trigger'
        recovery_msg 1
        r_longdata "name:{TRIGGER.NAME}\r\nid:{TRIGGER.ID}\r\nstatus:{TRIGGER.STATUS}\r\nhostname:{HOSTNAME}\r\nip:{IPADDRESS}\r\nvalue:{TRIGGER.VALUE}\r\nevent_id:{EVENT.ID}\r\nseverity: {TRIGGER.SEVERITY}\r\n"
        r_shortdata 'resolve'
        severity node['bcpc']['zabbix']['severity']
    end

    cron 'submit-events-to-pagerduty' do
        minute '*'
        user 'zabbix'
        command '/usr/local/bin/if_monitoring_vip /usr/lib/zabbix/alertscripts/pagerduty.py'
    end

end
