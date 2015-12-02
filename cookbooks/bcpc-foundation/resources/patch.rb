
# Cookbook Name:: bcpc
# Resource:: patch
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

actions :apply
default_action :apply

attribute :name, :name_attribute => true, :kind_of => String, :required => true
# patch_file is the path to a cookbook file (i.e., must be under files/)
attribute :patch_file, :kind_of => String, :required => true
# patch_root_dir is the directory from which the patch will be run
attribute :patch_root_dir, :kind_of => String, :required => true
# patch_level corresponds to -p with the patch command
attribute :patch_level, :kind_of => Integer, :default => 1
# these are cookbook file names that will be passed to shasum -c
# shasum is executed from patch_root_dir, so paths must be relative to
# that location within the checksum files
attribute :shasums_before_apply, :kind_of => String, :required => true
attribute :shasums_after_apply, :kind_of => String, :required => true
# the cookbook to find the files in (nil will use current cookbook)
attribute :file_cookbook, :kind_of => [NilClass, String], :required => false, :default => nil
