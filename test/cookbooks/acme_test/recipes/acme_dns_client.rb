node.default['osl-acme']['pebble']['always_valid'] = false
node.default['osl-acme']['pebble']['command'] = '/usr/local/bin/pebble -config /opt/pebble/test/config/pebble-config.json -dnsserver :8053'

build_essential 'osl-acme-test' do
  compile_time true
end

chef_gem 'bcrypt' do
  compile_time true
end

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

include_recipe 'osl-postgresql::server'

db_config = data_bag_item('osl_acme', 'database')

postgresql_database db_config['dbname']

postgresql_user db_config['user'] do
  database db_config['dbname']
  password db_config['pass']
  action :create
end

file '/var/lib/pgsql/12/data/pg_hba.conf' do
  content <<-EOF
local   all             all                                     trust
host    all             all             0.0.0.0/0               trust
  EOF
  notifies :reload, 'service[postgresql]', :immediately
end

#
# Configure acme-dns
#

osl_fakenic 'lo' do
  ip4 node['osl-acme']['acme-dns']['ns-address']
end

include_recipe 'osl-acme::server'
include_recipe 'osl-acme::acme_dns_server'
include_recipe 'osl-acme::default'

# Create test records
credentials = data_bag_item('osl_acme', 'credentials')['credentials']
subdomain_values = credentials.map { |_, creds| "('\"'\"'#{creds['subdomain']}'\"'\"')" }.join(',')
record_values = credentials.map { |_, creds| "('\"'\"'#{creds['username']}'\"'\"', '\"'\"'#{creds['subdomain']}'\"'\"', '\"'\"'#{make_password(creds['key'])}'\"'\"', '\"'\"'[]'\"'\"')" }.join(',')
test_subdomains = credentials.map { |_, creds| "subdomain = '#{creds['subdomain']}'" }.join(' OR ')

execute 'Create acme-dns records' do
  command <<-EOF
    psql -U #{db_config['user']} #{db_config['dbname']} -c '
      INSERT INTO records (username, subdomain, password, allowfrom)
      VALUES #{record_values}
      ON CONFLICT DO NOTHING' &&
    psql -U #{db_config['user']} #{db_config['dbname']} -c '
      INSERT INTO txt (subdomain)
      VALUES #{subdomain_values}
      ON CONFLICT DO NOTHING'
  EOF

  only_if <<-EOF
    sleep 15 &&
    psql -U #{db_config['user']} #{db_config['dbname']} -c "
      SELECT COUNT(*) FROM records
      WHERE #{test_subdomains}" |
    tr -d '\n' |
    grep -P 'count -------     0'
  EOF
end

#
# Get certificates for the specified hosts
#

records = data_bag_item('osl_acme', 'records')['records']
records.each do |record|
  get_acme_cert record['domain'] do
    contact 'mailto:andrewda@osuosl.org'
    acme_directory node['acme']['dir']
    acme_dns_api node['osl-acme']['acme-dns']['api']
    cert_path "/tmp/#{record['domain']}.pem"
    key_path "/tmp/#{record['domain']}.key"

    alt_names record['alt_names']
  end
end
