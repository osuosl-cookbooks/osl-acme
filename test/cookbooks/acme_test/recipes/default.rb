include_recipe 'osl-acme'
include_recipe 'osl-apache'
include_recipe 'apache2::mod_ssl'

apache_app 'foo.org' do
  directory '/var/www/foo.org/htdocs'
  ssl_enable true
  cert_file '/etc/pki/tls/foo.org.crt'
  cert_key '/etc/pki/tls/foo.org.key'
end

acme_selfsigned 'foo.org' do
  crt '/etc/pki/tls/foo.org.crt'
  key '/etc/pki/tls/foo.org.key'
  notifies :reload, 'service[apache2]', :immediately
end

acme_certificate 'foo.org' do
  crt '/etc/pki/tls/foo.org.crt'
  key '/etc/pki/tls/foo.org.key'
  wwwroot '/var/www/foo.org/htdocs'
  notifies :reload, 'service[apache2]'
end
