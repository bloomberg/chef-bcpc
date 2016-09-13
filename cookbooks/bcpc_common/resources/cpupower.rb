
# Cookbook Name:: bcpc_common
# Resource:: cpupower
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

actions :set
default_action :set

attribute :name, name_attribute: true, kind_of: String, required: true
attribute :governor, kind_of: String, required: true
attribute :ondemand_ignore_nice_load, kind_of: Integer, default: nil
attribute :ondemand_io_is_busy, kind_of: Integer, default: nil
attribute :ondemand_powersave_bias, kind_of: Integer, default: nil
attribute :ondemand_sampling_down_factor, kind_of: Integer, default: nil
attribute :ondemand_sampling_rate, kind_of: Integer, default: nil
attribute :ondemand_up_threshold, kind_of: Integer, default: nil
