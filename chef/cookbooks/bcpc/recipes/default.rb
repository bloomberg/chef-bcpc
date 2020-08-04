# Cookbook:: bcpc
# Recipe:: default
#
# Copyright:: 2020 Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

region = node['bcpc']['cloud']['region']
zone_config = ZoneConfig.new(node, region, method(:data_bag_item))

if zone_config.enabled? && worknode?
  if zone_config.zone.nil?
    raise 'zones are enabled but this node is not configured to be in a zone'
  end

  unless File.file?(zone_config.state_file)
    FileUtils.mkdir_p File.dirname(zone_config.state_file)
    File.write(zone_config.state_file, "#{zone_config.zone}\n")
  end

  zone = File.read(zone_config.state_file).strip
  unless zone == zone_config.zone
    msg = "the configured zone: '#{zone}', does not match"\
          " the target zone: '#{zone_config.zone}'"
    raise msg
  end
end
