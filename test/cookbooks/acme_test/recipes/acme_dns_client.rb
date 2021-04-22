chef_gem 'acme-client' do
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

postgresql_database 'testdb'

postgresql_user 'testuser' do
  database 'testdb'
  password 'testpass'
  action :create
end

file '/var/lib/pgsql/12/data/pg_hba.conf' do
  content <<-EOF
local   all             all                                     trust
host    all             all             0.0.0.0/0               trust
  EOF
  notifies :reload, 'service[postgresql]', :immediately
end

# Create some test records for acme-dns
execute 'create_acmedns_records' do
  command <<-EOF
    psql -U testuser testdb -c "
      INSERT INTO records (username, subdomain, password, allowfrom)
      VALUES ('cbfed1bb-c0b9-4b24-b212-5b95caa38f98', 'c8d6aeae-3f21-4786-b243-98bbd7c526a5', '\\$2a\\$10\\$f0laY/lEhiNhuNBqNlXqlOGP0OVNzg2mzDrI8bPYk3CTcOMDOFEuy', '[]'),
             ('c6853765-5036-4f01-9325-c7b97ee0fb2e', '2acca63e-1c34-4860-95f3-ba208dd8b0bc', '\\$2a\\$10\\$J8Dhe8YYcD44.KTCxHxdY.wUvL8aqvIjpObP6pKT4vVmk1HQet/Fi', '[]')" &&
    psql -U testuser testdb -c "INSERT INTO txt (subdomain) VALUES ('c8d6aeae-3f21-4786-b243-98bbd7c526a5'), ('2acca63e-1c34-4860-95f3-ba208dd8b0bc')"
  EOF

  only_if <<-EOF
    psql -U testuser testdb -c "
      SELECT COUNT(*) FROM records
      WHERE subdomain = 'c8d6aeae-3f21-4786-b243-98bbd7c526a5' OR subdomain = '2acca63e-1c34-4860-95f3-ba208dd8b0bc'" |
    tr -d '\n' |
    grep -P 'count -------     0'
  EOF

  action :nothing
end

#
# Configure acme-dns
#

execute 'add acme-dns ip' do
  command "ip addr add #{node['osl-acme']['acme-dns']['ns-address']} dev lo"
  not_if "ip a show dev lo | grep #{node['osl-acme']['acme-dns']['ns-address']}"
end

include_recipe 'osl-acme::server'
include_recipe 'osl-acme::acme_dns_server'
include_recipe 'osl-acme::default'

edit_resource(:docker_container, 'acme-dns.osuosl.org') do
  notifies :run, 'execute[create_acmedns_records]', :immediately
end

#
# Get certificates for the specified hosts
#

records = data_bag_item('osl_acme', 'records')['records']

records.each do |record|
  get_acme_cert record['domain'] do
    contact 'mailto:andrew@dassonville.dev'
    acme_directory node['acme']['dir']
    acme_dns_api node['osl-acme']['acme-dns']['api']
    acme_dns_api_subdomain record['subdomain']
    acme_dns_api_username record['username']
    acme_dns_api_key record['key']
    cert_path "/tmp/#{record['domain']}.pem"
  end
end
