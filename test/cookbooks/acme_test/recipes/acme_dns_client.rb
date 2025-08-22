node.default['osl-acme']['pebble']['always_valid'] = false
node.default['osl-acme']['pebble']['command'] = '/usr/local/bin/pebble -config /opt/pebble/test/config/pebble-config.json -dnsserver :8053'
node.default['osl-postgresql']['version'] = '16'

selinux_install 'test-selinux'

#
# Configure Bind
#

bind_service 'default' do
  action [:create, :start]
end

cookbook_file '/etc/named.conf'

directory '/var/named/master' do
  recursive true
end

template '/var/named/master/db.example.org' do
  source 'db.example.org.erb'
  notifies :restart, 'bind_service[default]', :immediately
end

#
# Setup PostgreSQL server
#

osl_postgresql_server 'default' do
  access 'access'
  databases 'databases'
  users 'users'
  action [:create, :start]
end

db_config = data_bag_item('osl_acme', 'database')

cookbook_file '/root/acmedns.sql'

execute 'import acmedns sql dump' do
  command "psql -h localhost -U #{db_config['user']} #{db_config['dbname']} < /root/acmedns.sql; touch /root/.db-imported"
  creates '/root/.db-imported'
end

selinux_permissive 'init_t'
selinux_permissive 'named_t'

#
# Configure acme-dns
#

osl_fakenic 'eth1' do
  ip4 node['osl-acme']['acme-dns']['ns-address']
end

include_recipe 'osl-acme::server'
include_recipe 'osl-acme::acme_dns_server'
include_recipe 'osl-acme::default'

#
# Get certificates for the specified hosts
#

dns_acme_certs 'Get ACME certificates' do
  records data_bag_item('osl_acme', 'records')['records']
  acme_directory node['acme']['dir']
  acme_dns_api node['osl-acme']['acme-dns']['api']
end
