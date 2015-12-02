#
# Cookbook Name:: bcpc-networking
# Recipe:: link-test
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

ruby_block "network-link-test" do
  block do
    othernodes = []
    float_addr = []
    storage_addr = []

    # prepare tests for ping testing peers
    ruby_block "setup-other-hosts" do
      block do
        get_all_nodes.each do |host|
          if (not othernodes.include? host) and host.roles.include? "component-bcpc-node-common" and
              host['hostname'] != node['hostname']
            Chef::Log.info("Found a peer : #{host.hostname}")
            othernodes.push host
            float_addr.push host['bcpc']['floating']['ip']
            storage_addr.push host['bcpc']['storage']['ip']
          end
        end
        # if there are no other nodes, then I am the first. If so, ensure
        # the tests will still pass by referencing myself
        if othernodes.empty?
          Chef::Log.info("No peers, using self : #{node['hostname']}")
          othernodes.push node
          float_addr.push node['bcpc']['floating']['ip']
          storage_addr.push node['bcpc']['storage']['ip']
        end
      end
    end

    # Run tests

    # There is no test for the management network. It must be up if we can
    # Chef it

    #
    # Test that we can ping at least one storage network peer.
    #
    # The aim of this test is to help during initial cluster build, when
    # the network may not have been debugged. We do not want to join
    # cluster members to the existing cluster unless they have the full
    # complement of network links
    #
    # Later on, however, if perhaps there have been some failures, we do
    # not want to prevent recovery by preventing chef from running in
    # scenarios we can't anticipate. Therefore this test disables itself
    # once it has passed once. To re-enable, simply remove the success
    # file by hand

    ruby_block "check-peers" do
      block do
        unless File.file?("/etc/storage-test-success")
          ping_node_list("storage peers", storage_addr)
          FileUtils.touch("/etc/storage-test-success")
        end

        unless File.file?("/etc/floating-test-success")
          ping_node_list("floating peers", float_addr)
          FileUtils.touch("/etc/floating-test-success")
        end
      end
    end
  end
  only_if { node['bcpc']['enabled']['network_tests'] }
end
