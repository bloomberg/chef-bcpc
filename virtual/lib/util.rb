module Util
  # initialize constants
  # ## virtualbox private network suffix to use
  # * control by environment variable 'ENABLE_VBOX_SUFFIX'
  # * set and non-empty -> set to a static hash base off full path of this file
  # * not set or empty -> set to empty (as if there's no suffix)
def self.vbox_name(name:) 
  # return name if suffix not enabled
  unless ENV.key?('ENABLE_VBOX_SUFFIX')
    return name
  end

  # return name + hashed __dir__
  require 'digest/sha1'
  hash = Digest::SHA1.hexdigest(__dir__)[0,7]
  return name + '_' + hash
end
    if ENV.key?('ENABLE_VBOX_SUFFIX') && !ENV['ENABLE_VBOX_SUFFIX'].empty?
      require 'digest'
      seed = Digest::SHA1.hexdigest __dir__
      rgen = Random.new(seed.hex)
      space = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map(&:to_a).flatten
      hash = (0...5).map { space[rgen.rand(space.length)] }.join
      suffix = '_' + hash
    else
      suffix = ''
    end
    suffix
  end

  def self.vbox_name(name)
    name + VBOX_SUFFIX
  end

  def self.mount_apt_cache(config)
    user_data_path = Vagrant.user_data_path.to_s
    cache_dir = File.join(user_data_path, 'cache', 'apt', config.vm.box)
    apt_cache_dir = '/var/cache/apt/archives'
    config.vm.synced_folder cache_dir, apt_cache_dir,
        create: true, owner: '_apt'
  end
end
