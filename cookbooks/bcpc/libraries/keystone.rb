def execute_in_keystone_admin_context(cmd, debug=false)
  new_env = ENV.reject {|name,val| name.start_with? 'OS_'}.tap do |env|
    env['OS_TOKEN']="#{get_config('keystone-admin-token')}"
    env['OS_URL']="#{node['bcpc']['protocol']['keystone']}://openstack.#{node['bcpc']['cluster_domain']}:#{node['bcpc']['catalog']['identity']['ports']['admin']}/#{node['bcpc']['catalog']['identity']['uris']['admin']}/"
  end
  script = <<-EoS
    . /root/api_versionsrc ;
    #{cmd}
  EoS
  script = "set -x;\n" + script if debug
  # Call script with new environment
  env(new_env){ %x[ #{script} ] }
end
