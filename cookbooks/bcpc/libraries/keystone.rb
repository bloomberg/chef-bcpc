require 'shellwords'

def construct_env
  new_env = ENV.reject {|name,val| name.start_with? 'OS_' or name == 'LS_COLORS'}.tap do |env|
    env['OS_TOKEN']="#{get_config('keystone-admin-token')}"
    env['OS_URL']="#{node['bcpc']['protocol']['keystone']}://openstack.#{node['bcpc']['cluster_domain']}:#{node['bcpc']['catalog']['identity']['ports']['admin']}/#{node['bcpc']['catalog']['identity']['uris']['admin']}/"
  end
  new_env
end

def execute_in_keystone_admin_context(cmd, debug=false)
  new_env = construct_env
  script = ". /root/api_versionsrc ; #{cmd}"
  if debug
    puts "\n" + new_env.to_s + "\n" + script
  end
  # Call script with new environment
  env(new_env) do
    cmd = 'bash -e -c ' + Shellwords.escape(script)
    o, e, s = Open3.capture3(cmd)
    puts o if debug
    s.success?
  end
end

def get_keystone_role_id(role, debug=false)
  new_env = construct_env
  script = ". /root/api_versionsrc ; openstack role show -f value -c id " + role
  if debug
    puts "\n" + new_env.to_s + "\n" + script
  end
  # Call script with new environment
  env(new_env) do
    cmd = 'bash -e -c ' + Shellwords.escape(script)
    o, e, s = Open3.capture3(cmd)
    raise unless s.success? and !o.empty?
    o.strip
  end
end

def keystone_db_version
  %x[keystone-manage db_version].strip
end
