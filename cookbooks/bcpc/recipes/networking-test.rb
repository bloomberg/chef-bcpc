#
# Cookbook Name:: bcpc
# Recipe:: networking-test
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

othernodes=[]

ruby_block "setup-other-hosts" do
  block do
    get_all_nodes.each do |host|
      if host.hostname != node.hostname then
        othernodes.push host
      end
    end
    # if there are no other nodes, then I am the first. If so, ensure
    # the tests will still pass by referencing myself
    if othernodes.empty? then
      othernodes.push node
    end
  end
end

template "/etc/floating-peers" do
  source "floating-peers.erb"
  mode 0644
  variables( :servers => othernodes) 
end


template "/etc/storage-peers" do
  source "storage-peers.erb"
  mode 0644
  variables( :servers => othernodes) 
end

# no test for management network. It must be up if we can chef it

bash "ping-storage-peers" do
  code <<-EOH
    # return 0 if ANY IP address responds
    while read IP; do
      ping -c1 ${IP} > /dev/null 2>&1
        if [[ $? = 0 ]]; then
          # this IP responds, network link must work
          exit 0
        fi
    done < /etc/storage-peers
    # if none found, cannot proceed
    echo "Network test failed : no storage peers respond, perhaps the cable is bad"
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    echo "- Network test failed : no storage peers respond, perhaps the cable is bad  -"
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    exit 1
  EOH
end


bash "ping-floating-peers" do
  code <<-EOH
    # return 0 if ANY IP address responds
    while read IP; do
      ping -c1 ${IP} > /dev/null 2>&1
        if [[ $? = 0 ]]; then
          # this IP responds, network link must work
          exit 0
        fi
    done < /etc/floating-peers
    # if none found, cannot proceed
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    echo "- Network test failed : no floating peers respond, perhaps the cable is bad -"
    echo "-----------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------"
    exit 1
  EOH
end




