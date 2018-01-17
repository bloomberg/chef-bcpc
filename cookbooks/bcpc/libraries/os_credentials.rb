class BadUserContextDriver < ArgumentError ; end

# simple mapping of usernames to *local* credential files
# for overrides ; see adminrc vs admin-openrc files...
USER_CRED_FILES = {
  'admin' => '/root/openrc-admin-domain'
}

def _get_cred_filename(username)
  basedir = '/root'
  name = File.join(basedir, 'openrc-' + username)
  USER_CRED_FILES[username] || name
end

def user_context_from_file(filename)
  cmd = "env - /bin/bash -c '2>/dev/null . #{filename} && printenv'"
  res = %x( #{cmd} )
  return nil if res.empty?
  # split by '=' and create the hash
  Hash[ *(res.split("\n").collect {|stmt|
    var,name = stmt.split('=') }.select {|name, val| name.match /^OS/ }.flatten)
  ].tap {|obj|
    return nil if obj.empty?
  }
end

# TODO(kamidzi): quite messy..
def user_context_from_memory(username)
  service_accounts = ['cinder', 'nova', 'glance']
 
  _proto = node['bcpc']['protocol']['keystone']
  _dnsdomain = node['bcpc']['cluster_domain']
  _port = node['bcpc']['catalog']['identity']['ports']['admin']
  _uri = node['bcpc']['catalog']['identity']['uris']['admin']
  admin_project_name = node['bcpc']['keystone']['admin']['project_name']
  service_project_name = node['bcpc']['keystone']['service_project']['name']
  service_project_domain = node['bcpc']['keystone']['service_project']['domain']
  service_user_domain = service_project_domain
  auth_url = "#{_proto}://openstack.#{_dnsdomain}:#{_port}/#{_uri}/"
  region = node['bcpc']['region_name']
  pass_key = "keystone-#{username}-password"

  default_env = {
    'OS_AUTH_URL' => auth_url,
    'OS_COMPUTE_API_VERSION' => get_api_version(:compute),
    'OS_IDENTITY_API_VERSION' => get_api_version(:identity),
    'OS_IMAGE_API_VERSION' => get_api_version(:image),
    'OS_NO_CACHE' => '1',
    'OS_PROJECT_DOMAIN_NAME' => service_project_domain,
    'OS_PROJECT_NAME' => service_project_name,
    'OS_REGION_NAME' => region,
    'OS_USER_DOMAIN_NAME' => service_user_domain,
    'OS_VOLUME_API_VERSION' => get_api_version(:volume),
  }

  # prefer the local admin
  user_context_mapping = {
    'admin' => default_env.merge({
      'OS_PASSWORD' => get_config('keystone-local-admin-password'),
      'OS_PROJECT_NAME' => admin_project_name,
      'OS_USERNAME' => 'admin',
    })
  }

  service_accounts.each {|user|
    h = default_env.dup
    begin
      h['OS_USERNAME'] = user
      h['OS_PASSWORD'] = get_config(pass_key)
    rescue
    # Just drop the whole thing
      h = nil 
    end
    user_context_mapping[user] = h
  }
  user_context_mapping[username]
end

def user_context(username, driver=:file)
  case driver
  when :file
    filename = _get_cred_filename(username)
    environ = user_context_from_file(filename)
  when :memory
    environ = user_context_from_memory(username)
  else
    raise BadUserContextDriver
  end
  if block_given?
    env(environ) do
      return yield
    end
  end
  environ
end

# For that admin context. For other admin users, can call
# user_context(admin_name) { commands }
def admin_context(driver=:file, &block)
  username='admin'
  user_context(username, driver) do
    yield
  end
end
