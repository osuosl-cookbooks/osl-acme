#
# Cookbook:: osl-acme
# Recipe:: acme_dns
#
# Copyright:: 2017-2021, Oregon State University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Enable live-restore to keep containers running when docker restarts
node.override['osl-docker']['service'] = { misc_opts: '--live-restore' }

include_recipe 'osl-docker'

directory '/etc/acme-dns/config' do
  recursive true
  action :create
end

db_config = data_bag_item('osl_acme', 'database')

template '/etc/acme-dns/config/config.cfg' do
  source 'config.cfg.erb'
  variables(pg_host: db_config['host'],
            pg_user: db_config['user'],
            pg_pass: db_config['pass'],
            pg_dbname: db_config['dbname'])
  notifies :restart, 'docker_container[acme-dns.osuosl.org]'
end

dns_address = if node['osl-acme']['acme-dns']['ns-address']
                node['osl-acme']['acme-dns']['ns-address'] + ':'
              else
                ''
              end

docker_image 'joohoi/acme-dns' do
  tag node['osl-acme']['acme-dns']['version']
  action :pull
end

docker_container 'acme-dns.osuosl.org' do
  repo 'joohoi/acme-dns'
  tag node['osl-acme']['acme-dns']['version']
  restart_policy 'always'
  port ['80:80', '443:443', "#{dns_address}53:53/tcp", "#{dns_address}53:53/udp"]
  volumes ['/etc/acme-dns/config:/etc/acme-dns:ro']
end
