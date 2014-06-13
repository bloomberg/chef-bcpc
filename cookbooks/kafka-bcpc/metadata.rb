# encoding: utf-8

name             'kafka-bcpc'
maintainer       'Unsupported'
description      'Ad-Hoc Recipe to setup prerequisites for Kafka server'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.0.0'

depends "kafka"
depends "sysctl"
depends "bcpc-hadoop"

%w(ubuntu).each do |os|
  supports os
end
