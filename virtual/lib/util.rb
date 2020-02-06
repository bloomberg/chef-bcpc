module Util


# get virtualbox private network suffix to use
# * set to environment variable 'VBOX_NET_SUFFIX'
# * default to login name (eg: _login)
# * eg: VBOX_NET_SUFFIX = ENV['VBOX_NET_SUFFIX'] || '_'+ENV['USER']
VBOX_NET_SUFFIX = begin 
  suffix = '_' + ENV['USER']
  if ENV.has_key? 'VBOX_NET_SUFFIX'
    suffix = ENV['VBOX_NET_SUFFIX']
  end
  suffix
end

def Util.privnet_args(name, nic_type: '82543GC', macaddr: nil)
  vbox_args = { }
  vbox_args[:virtualbox__intnet] = name+VBOX_NET_SUFFIX
  vbox_args[:nic_type] = nic_type
  vbox_args[:auto_config] = false
  if not macaddr.nil?
    if not macaddr.scan(/\D/).empty?
      raise "mac address to virtualbox should only be numbers (got #{macaddr})"
    end
    vbox_args[:mac] = macaddr
  end
  return vbox_args
end

def Util.mount_apt_cache(config)
  user_data_path = Vagrant.user_data_path.to_s
  cache_dir = File.join(user_data_path, 'cache', 'apt', config.vm.box)
  apt_cache_dir = '/var/cache/apt/archives'
  config.vm.synced_folder cache_dir, apt_cache_dir, create: true, owner: '_apt'
end

end
