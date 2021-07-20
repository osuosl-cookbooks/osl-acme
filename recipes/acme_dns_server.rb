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

acme_dns_version = node['osl-acme']['acme-dns']['version']
dns_address = node['osl-acme']['acme-dns']['ns-address'] || '0.0.0.0'

db_config = data_bag_item('osl_acme', 'database')

directory '/etc/acme-dns' do
  recursive true
end

remote_file "#{Chef::Config[:file_cache_path]}/acme-dns.tar.gz" do
  source "https://github.com/joohoi/acme-dns/releases/download/v#{acme_dns_version}/acme-dns_#{acme_dns_version}_linux_amd64.tar.gz"
  checksum node['osl-acme']['acme-dns']['checksum']
  mode '0755'
  notifies :extract, "archive_file[#{Chef::Config[:file_cache_path]}/acme-dns.tar.gz]", :immediately
end

archive_file "#{Chef::Config[:file_cache_path]}/acme-dns.tar.gz" do
  destination '/etc/acme-dns'
  overwrite true
  action :nothing
  notifies :create, 'link[/usr/local/bin/acme-dns]', :immediately
end

link '/usr/local/bin/acme-dns' do
  to '/etc/acme-dns/acme-dns'
  action :nothing
end

template '/etc/acme-dns/config.cfg' do
  source 'config.cfg.erb'
  variables(
    dns_interface: dns_address,
    pg_host: db_config['host'],
    pg_user: db_config['user'],
    pg_pass: db_config['pass'],
    pg_dbname: db_config['dbname']
  )
  sensitive true
  mode '0600'
  notifies :restart, 'systemd_unit[acme-dns.service]'
end

osl_firewall_dns 'dns'

osl_firewall_port 'http' do
  osl_only true
end

iptables_rule 'Restrict POST /register to localhost' do
  chain :INPUT
  line_number 1
  protocol :tcp
  match 'string'
  extra_options '--dport 80 --string "POST /register" --algo kmp'
  jump 'DROP'
end

systemd_unit 'acme-dns.service' do
  content <<~EOF
    [Unit]
    Description=Limited DNS server with RESTful HTTP API to handle ACME DNS challenges easily and securely
    After=network.target

    [Service]
    AmbientCapabilities=CAP_NET_BIND_SERVICE
    ExecStart=/usr/local/bin/acme-dns
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
  EOF
  action [:create, :enable, :start]
end
