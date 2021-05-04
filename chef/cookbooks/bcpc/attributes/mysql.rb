###############################################################################
# mysql
###############################################################################

# fqdn of mysql server
default['bcpc']['mysql']['host'] = 'primary.mysql.service.consul'

# port on which to accept incoming client connections
default['bcpc']['mysql']['port'] = 3306

default['bcpc']['mysql']['innodb_buffer_pool_instances'] = 16
default['bcpc']['mysql']['innodb_buffer_pool_size'] = '128M'
default['bcpc']['mysql']['innodb_flush_method'] = 'O_DIRECT_NO_FSYNC'
default['bcpc']['mysql']['innodb_io_capacity'] = 2048
default['bcpc']['mysql']['innodb_log_buffer_size'] = '256M'
default['bcpc']['mysql']['innodb_log_file_size'] = '128M'
default['bcpc']['mysql']['innodb_log_files_in_group'] = 4
default['bcpc']['mysql']['innodb_read_io_threads'] = 8
default['bcpc']['mysql']['innodb_write_io_threads'] = 8
default['bcpc']['mysql']['innodb_thread_concurrency'] = 128
default['bcpc']['mysql']['join_buffer_size'] = '128M'
default['bcpc']['mysql']['max_connections'] = 32768
default['bcpc']['mysql']['max_heap_table_size'] = '128M'
default['bcpc']['mysql']['sort_buffer_size'] = '1M'
default['bcpc']['mysql']['table_open_cache'] = 5120
default['bcpc']['mysql']['table_open_cache_instances'] = 8
default['bcpc']['mysql']['thread_cache_size'] = 1024
default['bcpc']['mysql']['tmp_table_size'] = '128M'
default['bcpc']['mysql']['wsrep_slave_threads'] = 16

# slow query log settings
default['bcpc']['mysql']['slow_query_log'] = true
default['bcpc']['mysql']['slow_query_log_file'] = '/var/log/mysql/slow.log'
default['bcpc']['mysql']['long_query_time'] = 10
default['bcpc']['mysql']['log_queries_not_using_indexes'] = false
