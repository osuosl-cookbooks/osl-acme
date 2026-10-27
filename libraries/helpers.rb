module OslAcme
  module Cookbook
    module Helpers
      require 'openssl'

      LEGO_PATH = '/var/lib/lego'.freeze
      LEGO_ENV = '/etc/lego/lego.env'.freeze
      NODE_EXPORTER_DIR = '/var/lib/node_exporter'.freeze

      def osl_acme_lego_path
        LEGO_PATH
      end

      def osl_acme_lego_env
        LEGO_ENV
      end

      # Returns [leaf, chain] from a PEM bundle, or nil if the first certificate doesn't parse
      def osl_acme_split_pem(bundle)
        certs = bundle.to_s.scan(/-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----\n?/m)
        return if certs.empty?
        OpenSSL::X509::Certificate.new(certs.first)
        [certs.first, certs.drop(1).join]
      rescue OpenSSL::X509::CertificateError
        nil
      end

      def osl_acme_key_matches?(cert_pem, key_pem)
        OpenSSL::X509::Certificate.new(cert_pem).check_private_key(OpenSSL::PKey.read(key_pem))
      rescue OpenSSL::OpenSSLError, ArgumentError
        false
      end

      def osl_acme_not_after(cert_pem)
        OpenSSL::X509::Certificate.new(cert_pem).not_after.to_i
      end

      def osl_acme_not_before(cert_pem)
        OpenSSL::X509::Certificate.new(cert_pem).not_before.to_i
      end

      # lego rejects --dns.propagation.wait together with disable-rns, so it's one or the other
      def osl_acme_lego_command(cert_name:, domains:, key_type:, propagation_wait: nil, resolvers: [])
        args = %w(/usr/local/bin/lego run --dns dnsupdate --force-cert-domains --no-random-sleep)
        args += ['--key-type', key_type, '--cert.name', cert_name]
        domains.each { |d| args += ['-d', d] }
        if propagation_wait
          args += ['--dns.propagation.wait', propagation_wait]
        else
          args << '--dns.propagation.disable-rns'
        end
        Array(resolvers).each { |r| args += ['--dns.resolvers', r] }
        args.join(' ')
      end

      def osl_acme_lego_env_content(email:, server:, nameserver:, zones:, tsig_file:, extra_env: {})
        env = {
          'LEGO_ACCEPT_TOS' => 'true',
          'LEGO_EMAIL' => email,
          'LEGO_SERVER' => server,
          'LEGO_PATH' => LEGO_PATH,
          'DNSUPDATE_NAMESERVER' => nameserver,
          'DNSUPDATE_ZONES' => Array(zones).join(','),
          'DNSUPDATE_TSIG_FILE' => tsig_file,
          'DNSUPDATE_PROPAGATION_TIMEOUT' => '300',
        }.merge(extra_env)
        env.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n"
      end

      def osl_acme_metrics_content(cert_name:, issued:, published:, not_after: nil, not_before: nil)
        label = "{cert=\"#{cert_name}\"}"
        lines = [
          '# HELP acme_cert_issued Whether lego on this node holds a certificate for the name.',
          '# TYPE acme_cert_issued gauge',
          "acme_cert_issued#{label} #{issued ? 1 : 0}",
          '# HELP acme_cert_published Whether the acme_certs data bag item matches lego\'s certificate.',
          '# TYPE acme_cert_published gauge',
          "acme_cert_published#{label} #{published ? 1 : 0}",
        ]
        if not_after
          lines += [
            '# HELP acme_cert_not_after_seconds Expiry of lego\'s certificate as a Unix timestamp.',
            '# TYPE acme_cert_not_after_seconds gauge',
            "acme_cert_not_after_seconds#{label} #{not_after}",
          ]
        end
        if not_before
          lines += [
            '# HELP acme_cert_not_before_seconds Start of lego\'s certificate validity as a Unix timestamp.',
            '# TYPE acme_cert_not_before_seconds gauge',
            "acme_cert_not_before_seconds#{label} #{not_before}",
          ]
        end
        lines.join("\n") + "\n"
      end

      # Plain write rather than a resource: it changes between converges and must not count as drift
      def osl_acme_write_metrics(cert_name, content, dir = NODE_EXPORTER_DIR)
        return if Chef::Config[:why_run] || !::File.directory?(dir)
        path = ::File.join(dir, "acme_cert_#{cert_name}.prom")
        return if ::File.exist?(path) && ::File.read(path) == content
        tmp = "#{path}.tmp"
        ::File.write(tmp, content)
        ::File.rename(tmp, path)
      end
    end
  end
end
Chef::DSL::Recipe.include ::OslAcme::Cookbook::Helpers
Chef::Resource.include ::OslAcme::Cookbook::Helpers
