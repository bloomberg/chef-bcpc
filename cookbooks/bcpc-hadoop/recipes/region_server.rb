

package "hbase-regionserver" do
  action :upgrade
end

service "hbase-regionserver" do
  action :enable
  subscribes :restart, "template[/etc/hbase/conf/hbase-site.xml]", :delayed
  subscribes :restart, "template[/etc/hbase/conf/hbase-policy.xml]", :delayed
end


