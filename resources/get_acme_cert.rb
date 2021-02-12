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

##################################################################################
# Steps:                                                                         #
# 1. OSL SysAdmin performs POST /register                                        #
# 2. OSL SysAdmin updates data bag to include response and the URL it's          #
#    associated with                                                             #
# 3. OSL/Client updates DNS records with a CNAME for:                            #
#    _acme-challenge.example.com => subdomain.acme-dns.osuosl.org                #
# 4. Merge data bag change                                                       #
# 5. Re-run Chef on the node which uses this resource to create certs (HAProxy?) #
#    5.1. Chef runs certbot-auto for new records
#    5.2. Cert is saved on disk
##################################################################################

action_class do
  require 'acme-client'
end

action :create do
  # Only run if cert doesn't exist, or is expiring in the next 24hr
  noExpire = system("openssl x509 -checkend 86400 -noout -in #{new_resource.cert_path}")
  return if noExpire

  client = Acme::Client.new(private_key: new_resource.private_key, directory: new_resource.acme_directory)
  client.new_account(contact: new_resource.contact, terms_of_service_agreed: true)
  order = client.new_order(identifiers: [new_resource.domain, *new_resource.alt_names])

  # Perform challenges for all identifiers
  order.authorizations.each do |authorization|
    puts "Performing challenge for #{authorization.identifier['value']}"

    challenge = authorization.dns

    # Update ACME DNS record
    uri = URI.parse("#{new_resource.acme_dns_api}/update")

    header = {'Content-Type': 'text/json'}
    body = {subdomain: new_resource.acme_dns_api_subdomain, txt: challenge.record_content}

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri, header)
    request.body = body.to_json
    request['X-Api-User'] = new_resource.acme_dns_api_username
    request['X-Api-Key'] = new_resource.acme_dns_api_key

    response = http.request(request)

    # TXT record is updated, request ACME validation
    challenge.request_validation

    # Wait for validation to complete
    while challenge.status == 'pending'
      sleep(2)
      challenge.reload
      puts "Status: #{challenge.status}"
    end

    puts "Challenge passed for #{authorization.identifier['value']}!"
  end

  # Challenges are valid, get cert
  csr = Acme::Client::CertificateRequest.new(common_name: new_resource.domain, names: new_resource.alt_names)
  order.finalize(csr: csr)
  while order.status == 'processing'
    sleep(1)
    order.reload
  end

  file new_resource.cert_path do
    content order.certificate
  end
end
