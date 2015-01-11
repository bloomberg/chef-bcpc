

def whyrun_supported?
  true
end

action :create do
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } already exists"
    if (@current_resource.pgp_num != @new_resource.pg_num and @new_resource.change_pg and @new_resource.change_pgp) or
      (@current_resource.pg_num < @new_resource.pg_num  and  @new_resource.change_pg ) or
      ( @current_resource.replicas != @new_resource.replicas) or
      (@current_resource.ruleset != @new_resource.ruleset)
      converge_by("Resetting pg(p)_num") do
        reset_pgs
      end
    end    
  else
    converge_by("Create #{ @new_resource }") do
      create_pool
    end
  end
end

action :delete do
 if not @current_resource.exists
    Chef::Log.info "#{ @new_resource } already deleted"    
  else
    converge_by("delete #{ @new_resource }") do
      delete_pool
    end
  end
  
end

def load_current_resource
  @current_resource = Chef::Resource::BcpcCephpool.new(@new_resource.name)
  @current_resource.exists = system("rados lspools | egrep '^#{@new_resource.name}$'") 
  if @current_resource.exists
	@current_resource.replicas (`ceph osd pool get  #{@new_resource.name} size  | awk '{}{print $2}' | tr -d '\n'`.to_i)
	@current_resource.pg_num(`ceph osd pool get #{@new_resource.name} pg_num | awk '{}{print $2}' | tr -d '\n'`.to_i)
	@current_resource.pgp_num = `ceph osd pool get #{@new_resource.name} pgp_num | awk '{}{print $2}' | tr -d '\n'`.to_i
	@current_resource.ruleset(`ceph osd pool get #{@new_resource.name} crush_ruleset | awk '{}{print $2}' | tr -d '\n'`.to_i)
  end
end

def create_pool
    system("ceph osd pool create #{new_resource.name} #{new_resource.pg_num}")
    system("ceph osd pool set #{new_resource.name} crush_ruleset #{new_resource.ruleset}")    
    system("ceph osd pool set #{new_resource.name} size #{new_resource.replicas}")
end

def delete_pool
     system("ceph osd pool create #{new_resource.name}  #{new_resource.name} --yes-i-really-really-mean-it")
end

def wait_for_pg_created
 while (`ceph -s | grep -v mdsmap | grep creating`.length > 0 ) do
   puts "waiting for pgs to create"
   sleep 1
 end
end

def reset_pgs
  if  @new_resource.change_pg and (@current_resource.pg_num < @new_resource.pg_num)
    system("ceph osd pool set #{new_resource.name} pg_num #{new_resource.pg_num}")    
    wait_for_pg_created
  end
  if  @new_resource.change_pg and @new_resource.change_pgp and (@current_resource.pgp_num != @new_resource.pg_num)
    system("ceph osd pool set #{new_resource.name} pgp_num #{new_resource.pg_num}")    
    wait_for_pg_created
  end
  if @current_resource.replicas != @new_resource.replicas
    system("ceph osd pool set #{new_resource.name} size #{new_resource.replicas}")    
  end
  if @current_resource.ruleset != @new_resource.ruleset
    system("ceph osd pool set #{new_resource.name} crush_ruleset #{new_resource.ruleset}")    
  end

end

