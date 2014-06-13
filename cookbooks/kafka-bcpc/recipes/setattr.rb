#
# Cookbook Name:: kafka-bcpc
# Recipe: setattr

# Override JAVA related node attributee
binary_server_url = get_binary_server_url

node.override['java']['jdk_version'] = '7'
node.override['java']['jdk']['7']['x86_64']['url'] = "#{binary_server_url}" + "jdk-7u51-linux-x64.tar.gz"
node.override['java']['jdk']['7']['i586']['url'] = "#{binary_server_url}" + "jdk-7u51-linux-i586.tar.gz"
log "Java x86_64 URL is #{node['java']['jdk']['7']['x86_64']['url']}"
log "Java i586 URL   is #{node['java']['jdk']['7']['i586']['url']}"

# Override Kafka related node attributes
@zk_hosts = get_nodes_for("zookeeper","kafka").map!{|x| x.bcpc.management.ip}
node.override[:kafka][:zookeeper][:connect] = @zk_hosts
node.override[:zookeeper][:servers] = @zk_hosts
node.override[:kafka][:base_url] = "#{binary_server_url}" + "kafka"
log "Kafka Base URL is #{node[:kafka][:base_url]}"

log "Disks are : #{node[:bcpc][:hadoop][:disks]}"
log "Mounts are : #{node[:bcpc][:hadoop][:mounts]}"
