node.default['osl-apache']['listen'] = %w(80 443)

include_recipe 'osl-acme'
include_recipe 'osl-apache'
include_recipe 'osl-apache::mod_ssl'

acme_selfsigned 'foo.org' do
  crt '/etc/pki/tls/foo.org.crt'
  key '/etc/pki/tls/foo.org.key'
  notifies :reload, 'apache2_service[osuosl]', :immediately
end

apache_app 'foo.org' do
  directory '/var/www/foo.org/htdocs'
  ssl_enable true
  cert_file '/etc/pki/tls/foo.org.crt'
  cert_key '/etc/pki/tls/foo.org.key'
end

acme_certificate 'foo.org' do
  crt '/etc/pki/tls/foo.org.crt'
  key '/etc/pki/tls/foo.org.key'
  wwwroot '/var/www/foo.org/htdocs'
  notifies :reload, 'apache2_service[osuosl]'
end
