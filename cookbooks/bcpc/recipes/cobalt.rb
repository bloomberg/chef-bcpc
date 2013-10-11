#
# Cookbook Name:: bcpc
# Recipe:: cobalt
#
# Copyright 2013, Bloomberg L.P.
# Copyright 2013, Gridcentric Inc.
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

include_recipe "bcpc::default"

apt_repository "cobalt" do
    uri node['bcpc']['repos']['gridcentric'] % ["cobalt", node['bcpc']['openstack_release']]
    distribution "gridcentric"
    components ["multiverse"]
    key "gridcentric.key"
end

apt_repository "cobaltclient" do
    uri node['bcpc']['repos']['gridcentric'] % ["cobaltclient", node['bcpc']['openstack_release']]
    distribution "gridcentric"
    components ["multiverse"]
    key "gridcentric.key"
end
