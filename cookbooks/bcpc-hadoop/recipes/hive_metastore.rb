include_recipe 'dpkg_autostart'

dpkg_autostart "hive-metastore" do
  allow false
end

%w{hive-metastore libmysql-java}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

link "/usr/lib/hive/lib/mysql.jar" do
  to "/usr/share/java/mysql.jar"
end


ruby_block "hive-metastore-database-creation" do
  cmd = "mysql -uroot -p#{get_config('mysql-root-password')} -e"
  privs = "SELECT,INSERT,UPDATE,DELETE,LOCK TABLES,EXECUTE" # todo node[:bcpc][:hadoop][:hive_db_privs].join(",")
  block do
    if not system " #{cmd} 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"metastore\"' | grep -q metastore" then
      code = <<-EOF
        CREATE DATABASE metastore;
        GRANT #{privs} ON metastore.* TO 'hive'@'%' IDENTIFIED BY '#{get_config('mysql-hive-password')}';
        GRANT #{privs} ON metastore.* TO 'hive'@'localhost' IDENTIFIED BY '#{get_config('mysql-hive-password')}';
        FLUSH PRIVILEGES;
        USE metastore;
        SOURCE /usr/lib/hive/scripts/metastore/upgrade/mysql/hive-schema-0.11.0-c5b1.mysql.sql;
        EOF
      IO.popen("mysql -uroot -p#{get_config('mysql-root-password')}", "r+") do |db|
        db.write code
      end
      self.notifies :enable, "service[hive-metastore]", :delayed
      self.resolve_notification_references
    end
  end
end

bash "create-hive-warehouse" do
  code "hadoop fs -mkdir -p /user/hive/warehouse; hadoop fs -chmod -R 1777 /user/hive/warehouse; hadoop fs -chown -R hive /user/hive"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /user/hive/warehouse"
end


service "hive-metastore" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hive/conf/hive-site.xml]", :delayed
  subscribes :restart, "template[/etc/hive/conf/hive-log4j.properties]", :delayed
end

