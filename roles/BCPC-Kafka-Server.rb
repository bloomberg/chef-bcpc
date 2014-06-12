require 'rubygems'
require 'ohai'

o = Ohai::System.new
o.all_plugins

name "BCPC-Kafka-Server"
description "Role to setup Kafka Server"
override_attributes "java" => {
    "jdk_version" => "7",
    "accept_license_agreement" => true,
    "oracle" => { "accept_oracle_download_terms" => true },
    "jdk" => {
               "7" => {
                        "x86_64" => { "url" => "http://10.0.100.3:80/jdk-7u51-linux-x64.tar.gz" },
                        "i586" => { "url" => "http://10.0.100.3:80/jdk-7u51-linux-i586.gz" }
                      }
    }
  },
  "kafka" => {
    "version" => "0.8.1",
    "scala_version" => "2.9.2",
    "checksum" => "",
    "md5_checksum" => "",
    "host_name" => o[:fqdn],
    "log_dir" => "/opt/kafka/kafka_logs",
    "base_url" => "http://10.0.100.3:80/kafka"
  },
  "zookeeper" => {
    "data_dir" => "/opt/kafka/zookeeper_data",
    "max_client_connections" => 50
  }
run_list "recipe[java::oracle]", "recipe[kafka-bcpc]", "recipe[kafka]"
