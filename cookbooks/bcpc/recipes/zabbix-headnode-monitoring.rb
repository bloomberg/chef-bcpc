template "/usr/local/etc/zabbix_agentd.conf.d/zabbix-openstack.conf" do
    source "zabbix_openstack.conf.erb"
    owner node[:bcpc][:zabbix][:user]
    group "root"
    mode 00600
    notifies :restart, "service[zabbix-agent]", :delayed
end

#
# Install functional checks, should return "OKAY" or "ERROR: <message>"
#
cookbook_file "/usr/local/bin/check_floats.py" do
  source "check_floats.py"
  owner node[:bcpc][:zabbix][:user]
  group "root"
  mode 00755  
end

service "zabbix-agent" do
    provider Chef::Provider::Service::Upstart
    action [ :enable, :start ]
end
