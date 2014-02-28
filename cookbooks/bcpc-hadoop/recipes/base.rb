# Install java 7
%w{openjdk-7-jdk}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

# set vm.swapiness to 0 (to lessen swapping)
sysctl_param 'vm.swappiness' do
  value 0
end

# disable IPv6 (e.g. for HADOOP-8568)
case node["platform_family"]
  when "debian"
    %w{net.ipv6.conf.all.disable_ipv6
       net.ipv6.conf.default.disable_ipv6
       net.ipv6.conf.lo.disable_ipv6}.each do |param|
      sysctl_param param do
        value 1
        notifies :run, "bash[restart_networking]", :delayed
      end
    end

    bash "restart_networking" do
      code "service networking restart"
      action :nothing
    end
  else
    Chef::Log.warn "============ Unable to disable IPv6 for non-Debian systems"
end

# File system setup
package "xfsprogs" do
  action :install
end

directory "/disk" do
  owner "root"
  group "root"
  mode 00755
  action :create
end

if node[:bcpc][:hadoop][:disks].length > 0 then
  node[:bcpc][:hadoop][:disks].each_index do |i|
    directory "/disk/#{i}" do
      owner "root"
      group "root"
      mode 00755
      action :create
      recursive true
    end
   
    d = node[:bcpc][:hadoop][:disks][i]
    execute "mkfs -t xfs -f /dev/#{d}" do
      not_if "file -s /dev/#{d} | grep -q 'SGI XFS filesystem'"
    end
 
    mount "/disk/#{i}" do
      device "/dev/#{d}"
      fstype "xfs"
      options "noatime,nodiratime,inode64"
      action [:enable, :mount]
    end

  end
  node.set[:bcpc][:hadoop][:mounts] = (0..node[:bcpc][:hadoop][:disks].length-1).to_a
else
  Chef::Application.fatal!('Please specify some node[:bcpc][:hadoop][:disks]!')
end

case node["platform_family"]
  when "debian"
    apt_repository "hortonworks" do
      uri node['bcpc']['repos']['hortonworks']
      distribution node[:bcpc][:hadoop][:distribution][:version]
      components ["contrib"]
      arch "amd64"
      key node[:bcpc][:hadoop][:distribution][:key]
    end

    %w{
      hadoop
      zookeeper
      hbase
      hive
      pig
    }.each do |w|
      directory "/etc/#{w}/conf.#{node.chef_environment}" do
        owner "root"
        group "root"
        mode 00755
        action :create
        recursive true
      end

      bash "update-#{w}-conf-alternatives" do
        code %Q{
         update-alternatives --install /etc/#{w}/conf #{w}-conf /etc/#{w}/conf.#{node.chef_environment} 50
         update-alternatives --set #{w}-conf /etc/#{w}/conf.#{node.chef_environment}
        }
      end
    end

  when "rhel"
    ""
    # do things on RHEL platforms (redhat, centos, scientific, etc)
end

make_config('mysql-hive-password', secure_password)

#
#set up hadoop conf
#
hadoop_conf_files = %w{capacity-scheduler.xml
   container-executor.cfg
   core-site.xml
   hadoop-metrics2.properties
   hadoop-metrics.properties
   hadoop-policy.xml
   hdfs-site.xml
   log4j.properties
   mapred-site.xml
   slaves
   ssl-client.xml
   ssl-server.xml
   yarn-site.xml
  }
node[:bcpc][:hadoop][:hdfs][:HA] == true and hadoop_conf_files.insert(-1,"hdfs-site_HA.xml")

if node['bcpc']['hadoop']['hdfs']['HA'] then
  nn_hosts = get_nodes_for("namenode*")
else
  nn_hosts = get_nodes_for("namenode_no_HA")
end

hadoop_conf_files.each do |t|
   template "/etc/hadoop/conf/#{t}" do
     source "hdp_#{t}.erb"
     mode 0644
     variables(:nn_hosts => nn_hosts,
               :zk_hosts => get_nodes_for("zookeeper_server"),
               :jn_hosts => get_nodes_for("journalnode"),
               :rm_host  => get_nodes_for("resource_manager"),
               :dn_hosts => get_nodes_for("datanode"),
               :hs_host => get_nodes_for("history_server"),
               :mounts => node[:bcpc][:hadoop][:mounts])
   end
end

%w{yarn-env.sh
  hadoop-env.sh}.each do |t|
 template "/etc/hadoop/conf/#{t}" do
   source "hdp_#{t}.erb"
   mode 0644
   variables(:nn_hosts => nn_hosts,
             :zk_hosts => get_nodes_for("zookeeper_server"),
             :jn_hosts => get_nodes_for("journalnode"),
             :mounts => node[:bcpc][:hadoop][:mounts])
 end
end

#
# Set up zookeeper configs
#
%w{zoo.cfg
  log4j.properties
  configuration.xsl
 }.each do |t|
 template "/etc/zookeeper/conf/#{t}" do
   source "zk_#{t}.erb"
   mode 0644
   variables(:nn_hosts => nn_hosts,
             :zk_hosts => get_nodes_for("zookeeper_server"),
             :jn_hosts => get_nodes_for("journalnode"),
             :mounts => node[:bcpc][:hadoop][:mounts])
 end
end

#
# Set up hbase configs
#
%w{hadoop-metrics.properties
   hbase-env.sh
   hbase-policy.xml
   hbase-site.xml
   log4j.properties
   regionservers}.each do |t|
   template "/etc/hbase/conf/#{t}" do
     source "hb_#{t}.erb"
     mode 0644
     variables(:nn_hosts => nn_hosts,
               :zk_hosts => get_nodes_for("zookeeper_server"),
               :jn_hosts => get_nodes_for("journalnode"),
               :rs_hosts => get_nodes_for("region_server"),
               :mounts => node[:bcpc][:hadoop][:mounts])
  end
end

#
# Set up hive configs
#
%w{hive-exec-log4j.properties
   hive-log4j.properties
   hive-site.xml }.each do |t|
   template "/etc/hive/conf/#{t}" do
     source "hv_#{t}.erb"
     mode 0644
     variables(:mysql_hosts => get_mysql_nodes.map{ |m| m.hostname },
               :zk_hosts => get_nodes_for("zookeeper_server"),
               :hive_host => get_nodes_for("hive_metastore"))
  end
end
