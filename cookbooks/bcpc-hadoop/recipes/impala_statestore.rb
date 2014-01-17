
package "impala-state-store" do
  action :upgrade
end

service "impala-state-store" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-policy.xml]", :delayed
  subscribes :restart, "template[/etc/hive/conf/hive-site.xml]", :delayed
end

