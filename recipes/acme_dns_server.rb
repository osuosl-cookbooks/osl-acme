#
# Cookbook:: osl-acme
# Recipe:: acme_dns_server
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

package 'glibc.i686'

user 'acme-dns' do
  system true
end

directory '/etc/acme-dns' do
  recursive true
  action :create
end

acme_dns_version = node['osl-acme']['acme-dns']['version']
remote_file '/etc/acme-dns/acme-dns.tar.gz' do
  source "https://github.com/joohoi/acme-dns/releases/download/v#{acme_dns_version}/acme-dns_#{acme_dns_version}_linux_386.tar.gz"
  checksum node['osl-acme']['acme-dns']['checksum']
  mode '0755'
  notifies :extract, 'archive_file[/etc/acme-dns/acme-dns.tar.gz]', :immediately
end

archive_file '/etc/acme-dns/acme-dns.tar.gz' do
  destination '/etc/acme-dns'
  overwrite true
  action :nothing
  notifies :create, 'link[/usr/local/bin/acme-dns]', :immediately
end

link '/usr/local/bin/acme-dns' do
  to '/etc/acme-dns/acme-dns'
  action :nothing
end

dns_address = node['osl-acme']['acme-dns']['ns-address'] || '0.0.0.0'

db_config = data_bag_item('osl_acme', 'database')

template '/etc/acme-dns/config.cfg' do
  source 'config.cfg.erb'
  variables(dns_interface: dns_address,
            pg_host: db_config['host'],
            pg_user: db_config['user'],
            pg_pass: db_config['pass'],
            pg_dbname: db_config['dbname'])
  notifies :restart, 'systemd_unit[acme-dns.service]'
end

systemd_unit 'acme-dns.service' do
  content <<-EOF.gsub(/^\s+/, '')
    [Unit]
    Description=Limited DNS server with RESTful HTTP API to handle ACME DNS challenges easily and securely
    After=network.target

    [Service]
    AmbientCapabilities=CAP_NET_BIND_SERVICE
    WorkingDirectory=~
    ExecStart=/usr/local/bin/acme-dns
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
  EOF
  action [:create, :enable, :start]
end
