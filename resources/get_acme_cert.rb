require 'net/http'
require 'acme-client'
require 'openssl'
require 'uri'
require 'json'

resource_name :get_acme_cert
provides :get_acme_cert

default_action :create

property :domain, String, default: lazy { name }
property :alt_names, Array, default: []
property :contact, String
property :acme_directory, String
property :acme_dns_api, String
property :acme_dns_api_subdomain, String
property :acme_dns_api_username, String
property :acme_dns_api_key, String
property :cert_path, String
property :private_key, OpenSSL::PKey::RSA, default: lazy { OpenSSL::Pkey::RSA.new(4096) }

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

action :create do
  client = Acme::Client.new(private_key: private_key, directory: acme_directory)
  client.new_account(contact: "mailto:#{contact}", terms_of_service_agreed: true)
  order = client.new_order(identifiers: [domain, *alt_names])

  # Perform challenges for all identifiers
  order.authorizations.each do |authorization|
    puts "Performing challenge for #{authorization.identifier['value']}"
    
    challenge = authorization.dns

    # Update ACME DNS record
    uri = URI.parse("#{acme_dns_api}/update")

    header = {'Content-Type': 'text/json'}
    body = {subdomain: subdomain, txt: challenge.record_content}

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri, header)
    request.body = body.to_json
    request['X-Api-User'] = username
    request['X-Api-Key'] = apikey

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
  csr = Acme::Client::CertificateRequest.new(common_name: domain, names: alt_names)
  order.finalize(csr: csr)
  while order.status == 'processing'
    sleep(1)
    order.reload
  end

  # Write certificate
  File.write(cert_path, order.certificate)
end

action :renew do

end
