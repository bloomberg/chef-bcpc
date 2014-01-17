
node[:bcpc][:hadoop][:mounts].each do |i|

  directory "/disk/#{i}/yarn/local" do
    owner "yarn"
    group "yarn"
    mode 0755
    action :create
    recursive true
  end

  directory "/disk/#{i}/yarn/logs" do
    owner "yarn"
    group "yarn"
    mode 0755
    action :create
    recursive true
  end

end


%w{hadoop-yarn-resourcemanager hadoop-client hadoop-mapreduce}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

service "hadoop-yarn-resourcemanager" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hadoop/conf/yarn-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/yarn-policy.xml]", :delayed
end


