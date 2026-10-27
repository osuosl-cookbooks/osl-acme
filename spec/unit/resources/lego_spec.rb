require_relative '../../spec_helper'

describe 'osl_acme_lego' do
  ALL_PLATFORMS.each do |p|
    context "#{p[:platform]} #{p[:version]}" do
      platform p[:platform], p[:version]
      cached(:subject) { chef_run }
      step_into :osl_acme_lego

      recipe do
        osl_acme_lego 'default' do
          tsig_file '/etc/named/acme-tsig.key'
        end
      end

      it do
        is_expected.to create_remote_file('/var/chef/cache/lego_v5.5.2_linux_amd64.tar.gz').with(
          source: 'https://github.com/go-acme/lego/releases/download/v5.5.2/lego_v5.5.2_linux_amd64.tar.gz',
          checksum: '2a35505089e7772c92e1e9ac144df91151ef2eca8568630db0ff91fca06d9bef'
        )
      end

      it do
        is_expected.to extract_archive_file('/var/chef/cache/lego_v5.5.2_linux_amd64.tar.gz').with(
          destination: '/opt/lego-5.5.2',
          owner: nil,
          group: nil
        )
      end

      it { is_expected.to create_link('/usr/local/bin/lego').with(to: '/opt/lego-5.5.2/lego') }
      it { is_expected.to create_directory('/etc/lego').with(mode: '0700') }
      it { is_expected.to create_directory('/var/lib/lego').with(mode: '0700') }

      it do
        is_expected.to create_file('/etc/lego/lego.env').with(
          mode: '0600',
          content: <<~EOF
            LEGO_ACCEPT_TOS=true
            LEGO_EMAIL=letsencrypt@osuosl.org
            LEGO_SERVER=https://acme-v02.api.letsencrypt.org/directory
            LEGO_PATH=/var/lib/lego
            DNSUPDATE_NAMESERVER=127.0.0.1
            DNSUPDATE_ZONES=acme.osuosl.org
            DNSUPDATE_TSIG_FILE=/etc/named/acme-tsig.key
            DNSUPDATE_PROPAGATION_TIMEOUT=300
          EOF
        )
      end
    end
  end
end
