#
# Cookbook Name:: bcpc
# Recipe:: phpmyadmin
#
# Copyright 2014, Bloomberg Finance L.P.
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
#

package "debconf-utils"

bash "phpmyadmin-debconf-setup" do
  make_config('mysql-phpmyadmin-password', secure_password)
  code <<-EOH
    set -e
    debconf-set-selections <<< 'phpmyadmin phpmyadmin/dbconfig-install boolean true'
    debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/admin-pass password #{get_config('mysql-root-password')}'
    debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/app-pass password #{get_config('mysql-phpmyadmin-password')}' 
    debconf-set-selections <<< 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' 
  EOH
  not_if "debconf-get-selections | grep phpmyadmin >/dev/null 2>&1"
end

package "phpmyadmin" do
  action :upgrade
end

bash "phpmyadmin-config-setup" do
  user "root"
  code <<-EOH
    echo '$cfg["AllowArbitraryServer"] = TRUE;' >> /etc/phpmyadmin/config.inc.php
  EOH
  not_if "grep -q AllowArbitraryServer /etc/phpmyadmin/config.inc.php"
end

template "/etc/apache2/vhost-ssl-root.d/phpmyadmin.conf" do
    source "apache-vhost-ssl-root-phpmyadmin.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end
