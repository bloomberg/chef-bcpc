#
# Name of jmxtrans software downloaded
#
default['jmxtrans']['sw']="jmxtrans-20120525-210643-4e956b1144.zip"
#
# Add additional JMX queries following the existing queries as sample
# Also refer to the jmxtrans community cookbook if queries of the category you are planning to add is
# already existing in the defualt attributes file
#
default['jmxtrans']['default_queries']['kafka'] = [
              {
                'obj' => "\\\"kafka.server\\\":type=\\\"BrokerTopicMetrics\\\",name=*",
                'result_alias' => "kafka.BrokerTopicMetrics",
                'attr' => [ "Count", "MeanRate", "OneMinuteRate", "FiveMinuteRate", "FifteenMinuteRate" ]
              },
              {
                'obj' => "\\\"kafka.server\\\":type=\\\"DelayedFetchRequestMetrics\\\",name=*",
                'result_alias' => "kafka.server.DelayedFetchRequestMetrics",
                'attr' => [ "Count", "MeanRate", "OneMinuteRate", "FiveMinuteRate", "FifteenMinuteRate" ]
              }
 ]
