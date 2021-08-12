module OslAcme
  module Cookbook
    module Helpers
      require 'net/http'
      require 'openssl'
      require 'uri'
      require 'json'

      # Gets an OpenSSL certificate at `path`, or nil if the file does not exist.
      def get_cert_or_nil(path)
        return OpenSSL::X509::Certificate.new(File.read(path)) if File.exist?(path)
      end

      # Gets an OpenSSL RSA key at `path`, or nil if the file does not exist.
      def get_key_or_nil(path)
        return OpenSSL::PKey::RSA.new(File.read(path)) if File.exist?(path)
      end

      # Creates an ACME client with the provided `private_key`, `directory` and `contact`.
      def create_client(private_key, directory, contact)
        require 'acme-client'
        client = Acme::Client.new(private_key: private_key, directory: directory)
        client.new_account(contact: contact, terms_of_service_agreed: true)
        client
      end

      # Performs the ACME challenge. Returns true if the challenge is completed successfully and
      # false if an issue occurred.
      def perform_challenge(authorization, subdomain, username, key, acme_dns_api)
        domain = authorization.identifier['value']
        challenge = authorization.dns

        Chef::Log.info("Performing challenge for #{domain}")

        # Check if challenge is already valid
        if challenge.status == 'valid'
          return true
        end

        # Update ACME DNS record
        uri = URI.parse("#{acme_dns_api}/update")

        header = { 'Content-Type': 'text/json', 'X-Api-User': username, 'X-Api-Key': key }
        body = { subdomain: subdomain, txt: challenge.record_content }

        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri, header)
        request.body = body.to_json

        response = http.request(request)

        # TXT record is updated, request ACME validation
        challenge.request_validation

        # Wait for validation to complete
        while challenge.status == 'pending'
          sleep(2)
          challenge.reload
        end

        # Check challenge status
        if challenge.status == 'valid'
          Chef::Log.info("Challenge passed for #{domain}!")
          true
        else
          Chef::Log.info("Challenge failed for #{domain}, status: #{challenge.status}")
          false
        end
      end

      # Finalize the ACME order and wait for it to finish processing.
      def finalize_order(order, domain, alt_names)
        require 'acme-client'

        # Create and certificate request and finalize order
        csr = Acme::Client::CertificateRequest.new(common_name: domain, names: alt_names)
        order.finalize(csr: csr)

        # Wait for order's status to change
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
