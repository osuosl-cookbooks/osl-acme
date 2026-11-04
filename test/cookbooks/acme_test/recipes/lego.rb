# DNS-01 end to end against Pebble: BIND on 127.0.0.2 because osl-acme::server's dnsmasq holds 127.0.0.1:53
include_recipe 'osl-acme::server'

package %w(bind bind-utils)

# BIND only listens on addresses an interface carries
execute 'ip addr add 127.0.0.2/8 dev lo' do
  not_if { shell_out('ip -4 addr show dev lo').stdout.include?('127.0.0.2/') }
end

file '/etc/named/acme-tsig.key' do
  content <<~EOF
    key "acme-lego" {
    \talgorithm hmac-sha256;
    \tsecret "dGVzdC1vbmx5LXRzaWcta2V5LWZvci1raXRjaGVuMDE=";
    };
  EOF
  group 'named'
  mode '0640'
  notifies :restart, 'service[named]'
end

# Pebble asks one TXT question and doesn't chase the CNAME, so BIND must answer it recursively
file '/etc/named.conf' do
  content <<~EOF
    options {
      directory "/var/named";
      listen-on port 53 { 127.0.0.2; };
      listen-on-v6 { none; };
      recursion yes;
      allow-recursion { localhost; };
      dnssec-validation no;
    };
    include "/etc/named/acme-tsig.key";
    zone "example.org" IN { type master; file "example.org.db"; };
    zone "acme.example.org" IN {
      type master;
      file "dynamic/db.acme.example.org";
      update-policy { grant acme-lego zonesub TXT; };
    };
  EOF
  group 'named'
  notifies :restart, 'service[named]'
end

file '/var/named/example.org.db' do
  content <<~EOF
    $TTL 60
    @	IN	SOA	ns1.example.org. hostmaster.example.org. ( 1 300 60 86400 60 )
    @	IN	NS	ns1.example.org.
    ns1	IN	A	127.0.0.2
    test	IN	A	127.0.0.1
    www	IN	A	127.0.0.1
    acme	IN	NS	ns1.example.org.
    _acme-challenge.test	IN	CNAME	test-example-org.acme.example.org.
    _acme-challenge.www	IN	CNAME	www-example-org.acme.example.org.
  EOF
  group 'named'
  notifies :restart, 'service[named]'
end

file '/var/named/dynamic/db.acme.example.org' do
  content <<~EOF
    $TTL 60
    @	IN	SOA	ns1.example.org. hostmaster.example.org. ( 1 300 60 86400 60 )
    @	IN	NS	ns1.example.org.
  EOF
  owner 'named'
  group 'named'
  action :create_if_missing
end

service 'named' do
  action [:enable, :start]
end

directory '/var/lib/node_exporter'

osl_acme_lego 'default' do
  server 'https://127.0.0.1:14000/dir'
  nameserver '127.0.0.2'
  zones 'acme.example.org'
  tsig_file '/etc/named/acme-tsig.key'
  extra_env('LEGO_CA_CERTIFICATES' => '/opt/pebble/test/certs/pebble.minica.pem')
end

# lego can't check the authoritative servers here: it looks up NS names through the system resolver
osl_acme_lego_cert 'test-example' do
  domains %w(test.example.org www.example.org)
  propagation_wait '2s'
  resolvers '127.0.0.2:53'
end

# Issue now rather than waiting for the timer; the guard keeps the second converge idempotent
service 'lego-test-example' do
  action :start
  not_if { ::File.exist?('/var/lib/lego/certificates/test-example.crt') }
end

osl_acme_lego_cert 'publish test-example' do
  cert_name 'test-example'
  action :publish
end
