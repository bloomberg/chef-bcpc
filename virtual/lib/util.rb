module Util
  # initialize constants
  # ## virtualbox private network suffix to use
  # * set to environment variable 'VBOX_NET_SUFFIX'
  # * default to a static hash
  # * eg: VBOX_NET_SUFFIX = ENV['VBOX_NET_SUFFIX'] || '_'+hash(__dir__)
  VBOX_NET_SUFFIX = begin
    if ENV.key? 'VBOX_NET_SUFFIX'
      suffix = ENV['VBOX_NET_SUFFIX']
    else
      require 'digest'
      seed = Digest::SHA1.hexdigest __dir__
      rgen = Random.new(seed.hex)
      space = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map(&:to_a).flatten
      hash = (0...5).map { space[rgen.rand(space.length)] }.join
      suffix = '_' + hash
    end
    suffix
  end

  def self.privnet_args(name, nic_type: '82543GC', macaddr: nil)
    vbox_args = {}
    vbox_args[:virtualbox__intnet] = name + VBOX_NET_SUFFIX
    vbox_args[:nic_type] = nic_type
    vbox_args[:auto_config] = false
    vbox_args[:mac] = macaddr unless macaddr.nil?
    vbox_args
  end

  def self.mount_apt_cache(config)
    user_data_path = Vagrant.user_data_path.to_s
    cache_dir = File.join(user_data_path, 'cache', 'apt', config.vm.box)
    apt_cache_dir = '/var/cache/apt/archives'
    config.vm.synced_folder cache_dir, apt_cache_dir,
        create: true, owner: '_apt'
  end
end
