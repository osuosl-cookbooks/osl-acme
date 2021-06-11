resource_name :dns_acme_certs
provides :dns_acme_certs
unified_mode true

default_action :create

property :records, Array, default: []
property :contact, String, default: lazy { node['acme']['contact'] }
property :acme_directory, String, default: lazy { node['acme']['dir'] }
property :acme_dns_api, String, default: lazy { node['osl-acme']['acme-dns']['api'] }
property :cert_path, String, default: '/etc/pki/tls'
property :key_path, String, default: '/etc/pki/tls'

action :create do
  new_resource.records.each do |record|
    dns_acme_cert record['domain'] do
      alt_names record['alt_names']

      contact new_resource.contact
      acme_directory new_resource.acme_directory
      acme_dns_api new_resource.acme_dns_api
      cert_path "#{new_resource.cert_path}/#{record['domain']}.pem"
      key_path "#{new_resource.key_path}/#{record['domain']}.key"
    end
  end
end
