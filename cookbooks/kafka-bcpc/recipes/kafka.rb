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
    @zk_host = "#{node[:kafka][:zookeeper][:connect][0]}:2181"
    while !znode_exists?(@brokerpath, @zk_host)
      if !znode_exists?(@brokerpath, @zk_host) and i < 10
        sleep(0.5)
        i += 1
        puts "Kafka server having znode #{@brokerpath} is down."
      elsif !znode_exists?(@brokerpath, @zk_host) and i > 9
        Chef::Application.fatal! "Kafka is reported down for more than 5 seconds"
      else
        puts "Broker #{@brokerid} existance : #{znode_exists?(@brokerpath, @zk_host)}"
      end
    end
    puts "Kafka is up and running."
  end
  action :nothing
end
