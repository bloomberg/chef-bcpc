template "/usr/local/etc/zabbix_agentd.conf.d/zabbix-openstack.conf" do
    source "zabbix_openstack.conf.erb"
    owner node[:bcpc][:zabbix][:user]
    group "root"
    mode 00600
    notifies :restart, "service[zabbix-agent]", :delayed
end

service "zabbix-agent" do
    provider Chef::Provider::Service::Upstart
    action [ :enable, :start ]
end
