include_recipe 'dpkg_autostart'

%w{hadoop-hdfs-journalnode}.each do |pkg|
  dpkg_autostart pkg do
    allow false
  end
  package pkg do
    action :upgrade
  end
end

node[:bcpc][:hadoop][:mounts].each do |i|
  directory "/disk/#{i}/dfs/jn/" do
    owner "hdfs"
    group "hdfs"
    mode 0755
    action :create
    recursive true
  end
  directory "/disk/#{i}/dfs/jn/#{node.chef_environment}" do
    owner "hdfs"
    group "hdfs"
    mode 0755
    action :create
    recursive true
  end
end

bash "initialize-shared-edits" do
  command "hdfs namenode -initializeSharedEdits"
  # need more than ., .., in_use.lock
  not_if { node[:bcpc][:hadoop][:mounts].all? { |i| Dir.entries("/disk/#{i}/dfs/jn/#{node.chef_environment}").include?("current") } }
end

service "hadoop-hdfs-journalnode" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
  subscribes :restart, "bash[initialize-shared-edits]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site_HA.xml]", :delayed
end



