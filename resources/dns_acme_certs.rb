resource_name :dns_acme_certs
provides :dns_acme_certs
unified_mode true

default_action :create

property :records, Array, required: true
property :contact, String
property :acme_directory, String
property :acme_dns_api, String
property :cert_dir, String
property :key_dir, String

action :create do
  new_resource.records.each do |record|
    dns_acme_cert record['domain'] do
      alt_names record['alt_names']

      contact new_resource.contact
      acme_directory new_resource.acme_directory
      acme_dns_api new_resource.acme_dns_api
      cert_path new_resource.cert_dir ? "#{new_resource.cert_dir}/#{record['domain']}.pem" : nil
      key_path new_resource.key_dir ? "#{new_resource.key_dir}/#{record['domain']}.key" : nil
    end
  end
end
