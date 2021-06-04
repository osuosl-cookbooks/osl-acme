require 'net/http'
require 'openssl'
require 'uri'
require 'json'

resource_name :get_acme_cert
provides :get_acme_cert
unified_mode true

default_action :create

property :domain, String, name_property: true
property :alt_names, Array, default: []
property :contact, String, default: lazy { node['acme']['contact'] }
property :acme_directory, String, default: lazy { node['acme']['dir'] }
property :acme_dns_api, String, default: lazy { node['osl-acme']['acme-dns']['api'] }
property :cert_path, String
property :key_path, String

action :create do
  existing_cert = get_cert_or_nil(new_resource.cert_path)

  # Check if an existing certificate exists that expires in more than 24 hours
  if existing_cert
    ttl = existing_cert.not_after - Time.now
    return if ttl > 86400
  end

  private_key = get_key_or_nil(new_resource.key_path)

  # If key does not exist, generate one and save to file
  unless private_key
    private_key = OpenSSL::PKey::RSA.new(2048)

    file new_resource.key_path do
      content private_key.export()
    end
  end

  client = create_client(private_key, new_resource.acme_directory, new_resource.contact)
  order = client.new_order(identifiers: [new_resource.domain, *new_resource.alt_names])

  credentials = data_bag_item('osl_acme', 'credentials')['credentials']

  # Perform challenges for all identifiers
  order.authorizations.each do |authorization|
    domain = authorization.identifier['value']
    domain_creds = credentials[domain]

    valid = perform_challenge(
      authorization,
      domain_creds['subdomain'],
      domain_creds['username'],
      domain_creds['key'],
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
