include_recipe 'dpkg_autostart'

%w{hue
   hue-beeswax
   hue-common
   hue-hbase
   hue-impala
   hue-pig
   hue-plugins
   hue-server
   hue-sqoop
   hue-zookeeper
}.each do |pkg|
  dpkg_autostart pkg do
    allow false
  end
  package pkg do
    action :upgrade
  end
end

ruby_block "hue-database-creation" do
  cmd = "mysql -u root -p#{get_config('mysql-root-password')} -e"
  privs = "ALL" # todo node[:bcpc][:hadoop][:hue_db_privs].join(",")
  block do

    if not system " #{cmd} 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"desktop\"' | grep -q desktop" then
           code = <<-EOF
                CREATE DATABASE desktop;
                GRANT #{privs} ON desktop.* TO 'hue'@'%' IDENTIFIED BY '#{get_config('mysql-hue-password')}';
                GRANT #{privs} ON desktop.* TO 'hue'@'localhost' IDENTIFIED BY '#{get_config('mysql-hue-password')}';
                FLUSH PRIVILEGES;
                EOF
           IO.popen("mysql -u root -p#{get_config('mysql-root-password')}", "r+") do |db|
             db.write code
           end
            self.notifies :enable, "service[hue]", :immediately
            self.resolve_notification_references
        end
    end
end

bash "create-hue-deployment" do
  code "hadoop fs -mkdir -p /user/hue/oozie/deployments; hadoop fs -chmod -R 1777 /user/hue/oozie; hadoop fs -chown -R hue /user/hue"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /user/hue/oozie"
end

bash "create-hue-oozie-workspace" do
  code "hadoop fs -mkdir -p /user/hue/oozie/workspaces; hadoop fs -chmod -R 1777 /user/hue/oozie; hadoop fs -chown -R hue /user/hue"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /user/hue/oozie/workspaces"
end

bash "create-hue-pig" do
  code "hadoop fs -mkdir -p /user/hue/pig/examples; hadoop fs -chmod -R 1777 /user/hue/pig; hadoop fs -chown -R hue /user/hue"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /user/hue/pig/examples"
end


service "hue" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hue/conf/hue.ini]", :delayed
end
