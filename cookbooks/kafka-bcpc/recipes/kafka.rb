#
# Cookbook Name:: kafka-bcpc 
# Recipe: Kafka

include_recipe "kafka::_configure"

begin
  r = resources("service[kafka]")
  r.notifies :create, "ruby_block[kafkaup]", :immediate
rescue Chef::Exceptions::ResourceNotFound
  Chef::Log.warn "Could not find service kafka to override!"
end

ruby_block "kafkaup" do
  i = 0
  block do
    @brokerpath="/brokers/ids/#{node[:kafka][:broker_id]}"
    #@zk_host = "#{node[:kafka][:zookeeper][:connect][0]}:2181"
    @zk_host = node[:kafka][:zookeeper][:connect].map{|zkh| "#{zkh}:2181"}.join(",")
    Chef::Log.info("Zookeeper hosts are #{@zk_host}")
    kafka_in_zk = znode_exists?(@brokerpath, @zk_host)
    while !kafka_in_zk
      kafka_in_zk = znode_exists?(@brokerpath, @zk_host)
      if !kafka_in_zk and i < 10
        sleep(0.5)
        i += 1
        Chef::Log.info("Kafka server having znode #{@brokerpath} is down.")
      elsif !kafka_in_zk and i > 9
        Chef::Application.fatal! "Kafka is reported down for more than 5 seconds"
      else
        Chef::Log.info("Broker #{@brokerpath} existance : #{znode_exists?(@brokerpath, @zk_host)}")
      end
    end
    Chef::Log.info("Kafka with znode #{@brokerpath} is up and running.")
  end
  action :nothing
end
