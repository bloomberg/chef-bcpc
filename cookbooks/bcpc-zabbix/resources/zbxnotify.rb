#
# Cookbook Name:: bcpc
# Resource:: zbxnotify
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


actions :create
default_action :create

# Name of the action
attribute :name, :name_attribute => true, :kind_of => String, :required => true
# Script to execute when action is triggered
attribute :script_filename, :kind_of => String, :required => true
# User alias of Zabbix recipient to notify
attribute :user_alias, :kind_of => String, :default => 'Admin'
# Identifier of the recipient
attribute :sendto, :kind_of => String, :required => true
# Time when the notifications can be sent
# Examples:
# 1. d-d,hh:mm-hh:mm
# 2. d-d,hh:mm-hh:mm;d-d,hh:mm-hh:mm
attribute :period, :kind_of => String, :default => '1-7,00:00-24:00'
# Trigger severities to send notifications about
attribute :severity, :kind_of => Fixnum, :default => 63
# Default operation step duration. Must be greater than 60 seconds.
attribute :esc_period, :kind_of => Fixnum, :default => 3600
# Type of events that the action will handle
# 0 = trigger
attribute :eventsource, :kind_of => Fixnum, :default => 0
# Problem message text
attribute :def_longdata, :kind_of => String, :default => "Trigger: {TRIGGER.NAME}\r\nTrigger status: {TRIGGER.STATUS}\r\nTrigger severity: {TRIGGER.SEVERITY}\r\nTrigger URL: {TRIGGER.URL}\r\n\r\nItem values:\r\n\r\n1. {ITEM.NAME1} ({HOST.NAME1}:{ITEM.KEY1}): {ITEM.VALUE1}\r\n2. {ITEM.NAME2} ({HOST.NAME2}:{ITEM.KEY2}): {ITEM.VALUE2}\r\n3. {ITEM.NAME3} ({HOST.NAME3}:{ITEM.KEY3}): {ITEM.VALUE3}\r\n\r\nOriginal event ID: {EVENT.ID}"
# Problem message subject
attribute :def_shortdata, :kind_of => String, :default => "{TRIGGER.STATUS}: {TRIGGER.NAME}"
# Whether recovery messages are enabled
# 0 - (default) disabled
# 1 - enabled
attribute :recovery_msg, :kind_of => Fixnum, :default => 0
# Recovery message text
attribute :r_longdata, :kind_of => String
# Recovery message subject
attribute :r_shortdata, :kind_of => String
attribute :status, :kind_of => Fixnum, :default => 0
