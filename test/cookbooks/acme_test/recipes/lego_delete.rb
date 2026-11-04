# Creates a certificate's units and metrics file once, then retires it with :delete
directory '/var/lib/node_exporter'

# The marker records that :create changed something; the second converge skips it to stay idempotent
osl_acme_lego_cert 'delete-example' do
  domains %w(delete.example.org)
  not_if { ::File.exist?('/var/tmp/lego-delete-created') }
  notifies :create, 'file[/var/tmp/lego-delete-created]', :immediately
end

file '/var/tmp/lego-delete-created' do
  action :nothing
end

osl_acme_lego_cert 'retire delete-example' do
  cert_name 'delete-example'
  action :delete
end
