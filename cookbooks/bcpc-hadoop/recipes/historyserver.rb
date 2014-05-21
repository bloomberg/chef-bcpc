
%w{hadoop-mapreduce-historyserver}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

%w{/mr-history/tmp /mr-history/done /app-logs}.each do |d|
  execute "create history server and applog directories" do
    command "sudo -u hdfs hdfs dfs -mkdir -p #{d}  && sudo -u hdfs hdfs dfs -chown -R 1777 #{d}"
  end
end

bash "chown history server directories" do
  code <<-EOH
   hdfs dfs -chown -R mapred:hadoop /mr-history 
  EOH
  user "hdfs"
end

bash "chown app log directory" do
  code <<-EOH
   hdfs dfs -chown yarn /app-logs
  EOH
  user "hdfs"
end

  
service "hadoop-mapreduce-historyserver" do
  action [:enable, :start]
end


