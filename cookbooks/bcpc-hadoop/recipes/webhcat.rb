
%w{hive-webhcat hive-hcatalog-server hive-hcatalog libmysql-java}.each do |p|
  package p do
    action :upgrade
  end
end

link "/usr/lib/hive/lib/mysql.jar" do
  to "/usr/share/java/mysql.jar"
end

%w{hive-hcatalog-server}.each do |s|
    service s do
      action [:enable, :start]
      subscribes :restart, "template[/etc/webhcat/conf/webhcat-site.xml]", :delayed
      subscribes :restart, "template[/etc/hive/conf/hive-site.xml]", :delayed
    end
  end
