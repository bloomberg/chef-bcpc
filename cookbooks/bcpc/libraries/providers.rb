def openstack_cli
  # Use file as last resort
  environ = user_context('admin', :memory) || user_context('admin', :file)
  env_cmd_args = cmdline_env_args(environ)
  args =  env_cmd_args + ["openstack"]
  return args
end

def nova_cli
  environ = user_context('admin', :memory) || user_context('admin', :file)
  env_cmd_args = cmdline_env_args(environ)
  args =  env_cmd_args + ["nova"]
  return args
end
