
%w{hadoop-mapreduce-historyserver}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

service "hadoop-mapreduce-historyserver" do
  action [:enable, :start]
end


