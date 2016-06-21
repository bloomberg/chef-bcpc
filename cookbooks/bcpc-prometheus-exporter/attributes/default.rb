###########################################
#
# Settings for Prometheus exporters
#
###########################################
default['bcpc-prometheus-exporter']['user'] = 'prometheus'
default['bcpc-prometheus-exporter']['group'] = 'prometheus'
default['bcpc-prometheus-exporter']['etc_dir'] = '/etc/prometheus'
default['bcpc-prometheus-exporter']['sbin_dir'] = '/usr/local/sbin'
default['bcpc-prometheus-exporter']['log_dir'] = '/var/log/prometheus'
default['bcpc-prometheus-exporter']['exporters'] = {
  'graphite_exporter' => {
    'parameters' => {
      'graphite.listen-address' => '127.0.0.1:2013',
      'graphite.mapping-config' => \
        "#{node['bcpc-prometheus-exporter']['etc_dir']}/"\
        + 'graphite_exporter-mapping.conf'
    }
  }
}
default['bcpc-prometheus-exporter']['logrotate'] = {
  'frequency' => 'daily',
  'rotate' => 30,
  'options' => %w( copytruncate compress missingok )
}
