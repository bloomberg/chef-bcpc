
%w{hadoop-mapreduce-historyserver hadoop-yarn-proxyserver}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

service "hadoop-yarn-proxyserver" do 
	action [:enable, :restart]
end

service "hadoop-yarn-historyserver" do 
	action [:enable, :restart]
end


