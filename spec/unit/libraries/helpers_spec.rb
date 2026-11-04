require_relative '../../spec_helper'
require_relative '../../../libraries/helpers'
require 'tmpdir'

describe OslAcme::Cookbook::Helpers do
  let(:helper) { Object.new.extend(described_class) }
  let(:pair) { osl_acme_test_pair }
  let(:other) { osl_acme_test_pair('other.example.org') }

  describe '#osl_acme_split_pem' do
    it 'splits the leaf from the chain' do
      expect(helper.osl_acme_split_pem(pair.first + other.first)).to eq [pair.first, other.first]
    end

    it 'returns an empty chain for a single certificate' do
      expect(helper.osl_acme_split_pem(pair.first)).to eq [pair.first, '']
    end

    it 'returns nil for a half-written file' do
      expect(helper.osl_acme_split_pem(pair[0][0, 200])).to be_nil
      expect(helper.osl_acme_split_pem('')).to be_nil
    end
  end

  describe '#osl_acme_key_matches?' do
    it { expect(helper.osl_acme_key_matches?(pair.first, pair[1])).to be true }
    it { expect(helper.osl_acme_key_matches?(pair.first, other[1])).to be false }
    it { expect(helper.osl_acme_key_matches?(pair.first, 'not a key')).to be false }
  end

  describe '#osl_acme_lego_command' do
    it 'checks only the authoritative servers by default' do
      expect(
        helper.osl_acme_lego_command(cert_name: 'download-ros', domains: %w(download.ros.osuosl.org download.ros.org), key_type: 'rsa2048')
      ).to eq '/usr/local/bin/lego run --dns dnsupdate --force-cert-domains --no-random-sleep --key-type rsa2048 ' \
              '--cert.name download-ros -d download.ros.osuosl.org -d download.ros.org --dns.propagation.disable-rns'
    end

    it 'swaps in a fixed wait and adds resolvers' do
      expect(
        helper.osl_acme_lego_command(cert_name: 'x', domains: %w(*.cinc.sh), key_type: 'ec256', propagation_wait: '2s', resolvers: %w(127.0.0.2:53))
      ).to eq '/usr/local/bin/lego run --dns dnsupdate --force-cert-domains --no-random-sleep --key-type ec256 ' \
              '--cert.name x -d *.cinc.sh --dns.propagation.wait 2s --dns.resolvers 127.0.0.2:53'
    end
  end

  describe '#osl_acme_lego_env_content' do
    it do
      expect(
        helper.osl_acme_lego_env_content(
          email: 'letsencrypt@osuosl.org', server: 'https://acme', nameserver: '127.0.0.1',
          zones: %w(acme.osuosl.org other.org), tsig_file: '/etc/named/acme-tsig.key', extra_env: { 'X' => 'y' }
        )
      ).to eq <<~EOF
        LEGO_ACCEPT_TOS=true
        LEGO_EMAIL=letsencrypt@osuosl.org
        LEGO_SERVER=https://acme
        LEGO_PATH=/var/lib/lego
        DNSUPDATE_NAMESERVER=127.0.0.1
        DNSUPDATE_ZONES=acme.osuosl.org,other.org
        DNSUPDATE_TSIG_FILE=/etc/named/acme-tsig.key
        DNSUPDATE_PROPAGATION_TIMEOUT=300
        X=y
      EOF
    end
  end

  describe '#osl_acme_metrics_content' do
    it 'leaves out the expiry before issue' do
      content = helper.osl_acme_metrics_content(cert_name: 'mc', issued: false, published: false)
      expect(content).to include("acme_cert_issued{cert=\"mc\"} 0\n", "acme_cert_published{cert=\"mc\"} 0\n")
      expect(content).to_not include('not_after', 'not_before')
    end

    it do
      content = helper.osl_acme_metrics_content(cert_name: 'mc', issued: true, published: true, not_after: 123, not_before: 100)
      expect(content).to include(
        "acme_cert_issued{cert=\"mc\"} 1\n",
        "acme_cert_not_after_seconds{cert=\"mc\"} 123\n",
        "acme_cert_not_before_seconds{cert=\"mc\"} 100\n"
      )
    end
  end

  describe '#osl_acme_write_metrics' do
    it 'writes into an existing directory and skips a missing one' do
      Dir.mktmpdir do |dir|
        helper.osl_acme_write_metrics('mc', "a 1\n", dir)
        expect(File.read(File.join(dir, 'acme_cert_mc.prom'))).to eq "a 1\n"
        expect(Dir.children(dir)).to eq %w(acme_cert_mc.prom)
        expect { helper.osl_acme_write_metrics('mc', "a 1\n", File.join(dir, 'missing')) }.to_not raise_error
      end
    end
  end
end
