# This is an ill-advised hack to handle the legacy of other ill-advised hacks.
# See keystone recipe for why this is necessary.
def has_unregistered_migration?
  migrate_repo = '/usr/lib/python2.7/dist-packages/keystone/common/sql/migrate_repo/versions'
  migration_filename = '098_migrate_single_to_multi_domain_user_ids.py'
  signal_file = File.join(migrate_repo, migration_filename)
  keystone_db_version == '98' and not ::File.exist?(signal_file)
end
