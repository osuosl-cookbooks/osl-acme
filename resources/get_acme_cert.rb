require 'net/http'
require 'openssl'
require 'uri'
require 'json'

resource_name :get_acme_cert
provides :get_acme_cert

default_action :create

property :domain, String, name_property: true
property :alt_names, Array, default: []
property :contact, String
property :acme_directory, String
property :acme_dns_api, String
property :acme_dns_api_subdomain, String
property :acme_dns_api_username, String
property :acme_dns_api_key, String
property :cert_path, String
property :private_key, OpenSSL::PKey::RSA, default: lazy { OpenSSL::PKey::RSA.new(4096) }

action :create do
  existing_cert = get_cert_or_nil(new_resource.cert_path)

  # Check if an existing certificate exists that expires in more than 24 hours
  if existing_cert
    ttl = existing_cert.not_after - Time.now
    return if ttl > 86400
  end

  client = create_client(new_resource.private_key, new_resource.acme_directory, new_resource.contact)
  order = client.new_order(identifiers: [new_resource.domain, *new_resource.alt_names])

  # Perform challenges for all identifiers
  order.authorizations.each do |authorization|
    valid = perform_challenge(
      authorization,
      new_resource.acme_dns_api_subdomain,
      new_resource.acme_dns_api_username,
      new_resource.acme_dns_api_key,
      new_resource.acme_dns_api
    )

    unless valid
      puts 'Challenge failed!'
      break
    end
  end

  # Challenges are valid, get cert
  finalize_order(order, new_resource.domain, new_resource.alt_names)

  file new_resource.cert_path do
    content order.certificate
  end
end
