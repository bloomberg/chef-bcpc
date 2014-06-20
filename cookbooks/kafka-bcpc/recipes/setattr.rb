#
# Cookbook Name:: kafka-bcpc
# Recipe: setattr

# Override JAVA related node attributee
node.override['java']['jdk_version'] = '7'
node.override['java']['jdk']['7']['x86_64']['url'] = get_binary_server_url + "jdk-7u51-linux-x64.tar.gz"
node.override['java']['jdk']['7']['i586']['url'] = get_binary_server_url + "jdk-7u51-linux-i586.tar.gz"
log "Java x86_64 URL is #{node['java']['jdk']['7']['x86_64']['url']}"
log "Java i586 URL   is #{node['java']['jdk']['7']['i586']['url']}"

# Override Kafka related node attributes
@zk_hosts = get_nodes_for("zookeeper","kafka").map!{|x| x.bcpc.management.ip}
log "ZK Hosts are : #{@zk_hosts}"

node.override[:kafka][:zookeeper][:connect] = @zk_hosts
log "node[kafka][zookeeper][connect] = #{node[:kafka][:zookeeper][:connect]}"

node.override[:zookeeper][:servers] = @zk_hosts
log "node[zookeeper][servers] = #{node[:zookeeper][:servers]}"

node.override[:kafka][:base_url] = get_binary_server_url + "kafka"
log "Kafka Base URL is #{node[:kafka][:base_url]}"

log "Disks are : #{node[:bcpc][:hadoop][:disks]}"
log "Mounts are : #{node[:bcpc][:hadoop][:mounts]}"

node.override[:kafka][:host_name] = float_host(node[:fqdn])
node.override[:kafka][:advertised_host_name] = float_host(node[:fqdn])

log "Kafka host name is : #{node[:kafka][:host_name]}"
log "Kafka advertised host name is : #{node[:kafka][:advertised_host_name]}"
