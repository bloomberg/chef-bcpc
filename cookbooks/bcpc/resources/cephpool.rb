#
# Cookbook Name:: bcpc
# Resource:: cephpool
#
actions :create, :delete 

default_action :create

attribute :name, :name_attribute => true, :kind_of => String, :required => true
attribute :pg_num, :kind_of => Fixnum, :required => true
attribute :change_pgp,  :kind_of => [ TrueClass, FalseClass ], :default => false
attribute :change_pg,  :kind_of => [ TrueClass, FalseClass ], :default => true
attribute :replicas    , :kind_of => Fixnum, :required => true
attribute :ruleset  , :kind_of => Fixnum, :required => true

attr_accessor :exists
attr_accessor :pgp_num

