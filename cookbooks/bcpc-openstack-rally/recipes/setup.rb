#
# Cookbook Name:: bcpc-openstack-rally
# Recipe:: setup
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

# Note: The rally.rb recipe must have already been executed before running this one.
# IMPORTANT: The head nodes MUST have already been installed and the keystone endpoints working. Rally verifies.
ruby_block "initialize-rally-keystone-config" do
    block do
        make_config('keystone-admin-token', secure_password)
        make_config('keystone-admin-user', "admin")
        make_config('keystone-admin-password', secure_password)
    end
end

# This json file represents the current deployment of OpenStack. It is read in a later section and then
# the information from the json file is created in Rally's database to be used for tests.
template "/opt/rally/existing.json" do
    user 'root'
    source "rally.existing.json.erb"
    owner node['bcpc']['rally']['user']
    group node['bcpc']['rally']['user']
    mode 0664
end

# Rally has an install_rally.sh but we're not using it since it attempts to make external calls. Instead we will
# the needed steps here...

# (1) - Install
# This was done during 'build_bins.sh' with the package build and then the 'rally.rb' recipe on the bootstrap node.
# It basically creates rally and rally-manage and puts them into the /usr/local/bin directory using pbr.

# (2) - Configure
# Inits the db. If a db already exists then this command will init back to an empty-clean state

bash "rally-db-recreate" do
    user 'root'
    code <<-EOH
        rally-manage db recreate
        chmod -R go+w /var/lib/rally
    EOH
end

# (3) - Deployment Configuration
# This step is very important since it reads (can also use environment variables) the json file that was
# created in an earlier part of this recipe.

# Note: The returns in this block can be pass or fail because it attempts to set the initial deployment up but if the
# head nodes are not responding then it will fail and will have to be ran again after the head nodes are up.
bash "rally-deployment-create" do
    user node['bcpc']['rally']['user']
    code <<-EOH
        rally deployment create --file=/opt/rally/existing.json --name=existing
        rally deployment use existing
    EOH
    returns [0, 1]
end
