package "libmysql-java" do
  action :upgrade
end

%w{hive-hcatalog hive-hcatalog-server hive-webhcat}.each do |p|
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
