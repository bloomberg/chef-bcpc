module Util
  # returns vbox_name with or without suffix base on set vs unset
  # of the environment var 'ENABLE_VBOX_SUFFIX'
  def self.vbox_name(name)
    # return name if suffix not enabled
    unless ENV.key?('ENABLE_VBOX_SUFFIX')
      return name
    end
    # return name + hashed __dir__
    require 'digest/sha1'
    hash = Digest::SHA1.hexdigest(__dir__)[0, 7]
    name + '_' + hash
  end

  def self.mount_apt_cache(config)
    user_data_path = Vagrant.user_data_path.to_s
    cache_dir = File.join(user_data_path, 'cache', 'apt', config.vm.box)
    apt_cache_dir = '/var/cache/apt/archives'
    config.vm.synced_folder cache_dir, apt_cache_dir,
        create: true, owner: '_apt'
  end
end
