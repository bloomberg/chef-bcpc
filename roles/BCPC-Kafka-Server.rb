require 'rubygems'
require 'ohai'

o = Ohai::System.new
o.all_plugins

name "BCPC-Kafka-Server"
description "Role to setup Kafka Server"
override_attributes "kafka" => {
    "version" => "0.8.1",
    "scala_version" => "2.9.2",
    "checksum" => "",
    "md5_checksum" => "",
    "host_name" => o[:fqdn],
    "log_dir" => "/disk/0"
  },
  "zookeeper" => {
    "data_dir" => "/disk/1",
    "max_client_connections" => 50
  }
run_list "role[Basic]", "recipe[bcpc]", "recipe[bcpc::networking]", "recipe[bcpc-hadoop::disks]", "recipe[java::oracle]", "recipe[kafka-bcpc]", "recipe[kafka]"
