#
# These functions require "partial_search" cookbook
# Upload "partial_searck" cookbook and then modify the metadata.rb file to 
# make "partial_search" cookbook as dependency. Then upload the bcpc_jmxtrans
# cookbook
#
def get_graphite_vip
  ret = []
  results = partial_search(:node, 'recipes:bcpc\:\:graphite', 
               :keys => { 'vip' => [ 'bcpc', 'graphite', 'ip' ]}).each do |result|
    ret << result['vip']
  end
  return ret.uniq[0]
end

def get_graphite_port
  ret = []
  results = partial_search(:node, 'recipes:bcpc\:\:graphite', 
               :keys => { 'vip' => [ 'bcpc', 'graphite', 'port' ]}).each do |result|
    ret << result['vip']
  end
  return ret.uniq[0]
end
