service 'systemd-timesyncd'

template '/etc/systemd/timesyncd.conf' do
  source 'timesyncd/timesyncd.conf.erb'
  notifies :restart, 'service[systemd-timesyncd]', :immediately
end
