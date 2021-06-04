module OslAcme
  module Cookbook
    module Helpers
      require 'net/http'
      require 'openssl'
      # require 'acme-client'
      require 'uri'
      require 'json'

      def get_cert_or_nil(path)
        return OpenSSL::X509::Certificate.new(File.read(path)) if File.exist?(path)
      end

      def get_key_or_nil(path)
        return OpenSSL::PKey::RSA.new(File.read(path)) if File.exist?(path)
      end

      def create_client(private_key, directory, contact)
        require 'acme-client'
        client = Acme::Client.new(private_key: private_key, directory: directory)
        client.new_account(contact: contact, terms_of_service_agreed: true)
        client
      end

      def request_record(acme_dns_api)
        # Update ACME DNS record
        uri = URI.parse("#{acme_dns_api}/request")

        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri, header)

        response = http.request(request)
        puts response.body
      end

      def perform_challenge(authorization, subdomain, username, key, acme_dns_api)
        puts "Performing challenge for #{authorization.identifier['value']}"

        challenge = authorization.dns

        # Update ACME DNS record
        uri = URI.parse("#{acme_dns_api}/update")

        header = { 'Content-Type': 'text/json' }
        body = { subdomain: subdomain, txt: challenge.record_content }

        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri, header)
        request.body = body.to_json
        request['X-Api-User'] = username
        request['X-Api-Key'] = key

        response = http.request(request)
        puts response.code
        puts response.body

        # TXT record is updated, request ACME validation
        challenge.request_validation

        # Wait for validation to complete
        while challenge.status == 'pending'
          sleep(2)
          challenge.reload
          puts "Status: #{challenge.status}"
        end

        puts challenge
        if challenge.status == 'valid'
          puts "Challenge passed for #{authorization.identifier['value']}!"
          true
        else
          puts "Challenge failed for #{authorization.identifier['value']}, status: #{challenge.status}"
          false
        end
      end

      def finalize_order(order, domain, alt_names)
        require 'acme-client'
        csr = Acme::Client::CertificateRequest.new(common_name: domain, names: alt_names)
        order.finalize(csr: csr)
        while order.status == 'processing'
          sleep(1)
          order.reload
        end
      end
    end
  end
end

Chef::DSL::Recipe.include ::OslAcme::Cookbook::Helpers
Chef::Resource.include ::OslAcme::Cookbook::Helpers
