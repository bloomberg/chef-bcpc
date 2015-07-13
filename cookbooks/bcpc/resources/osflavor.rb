#
# Cookbook Name:: bcpc
# Resource:: osflavor
#
# Copyright 2013, Bloomberg Finance L.P.
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


actions :create, :delete
default_action :create

attribute :name, :name_attribute => true, :kind_of => String, :required => true
attribute :flavor_id, :kind_of => String, :required => false, :default => "auto"
attribute :memory_mb, :kind_of => Fixnum, :required => false, :default => 512
attribute :disk_gb, :kind_of => Fixnum, :required => false, :default => 5
attribute :ephemeral_gb, :kind_of => Fixnum, :required => false, :default => 0
attribute :swap_gb, :kind_of => Fixnum, :required => false, :default => 0
attribute :vcpus, :kind_of => Fixnum, :required => false, :default => 1
attribute :is_public, :kind_of => [ TrueClass, FalseClass ], :required => false, :default => true
# extra_specs are used for things like host aggregates. Set to
# restrict flavors to particular compute nodes. 
attribute :extra_specs, :kind_of => Hash, :required => false, :default => {}
