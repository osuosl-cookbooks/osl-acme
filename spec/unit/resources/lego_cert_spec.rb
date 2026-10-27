require_relative '../../spec_helper'

describe 'osl_acme_lego_cert' do
  crt = '/var/lib/lego/certificates/download-ros.crt'
  key = '/var/lib/lego/certificates/download-ros.key'
  not_found = Net::HTTPClientException.new('404 "Not Found"', Net::HTTPResponse.new('1.1', '404', 'Not Found'))
  # What Chef::DataBagItem.load returns: raw_data, and [] for a plain item
  bag_item = Struct.new(:raw_data) do
    def [](key)
      raw_data[key]
    end
  end
  encrypted_item = ->(data, secret = 'secret') { bag_item.new(Chef::EncryptedDataBagItem.encrypt_data_bag_item(data, secret)) }

  ALL_PLATFORMS.each do |p|
    context "#{p[:platform]} #{p[:version]}" do
      platform p[:platform], p[:version]
      step_into :osl_acme_lego_cert

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:read).and_call_original
        # Never write into a real node_exporter directory on the machine running the specs
        allow(File).to receive(:directory?).and_call_original
        allow(File).to receive(:directory?).with('/var/lib/node_exporter').and_return(false)
      end

      context 'before lego has issued anything' do
        cached(:subject) { chef_run }

        recipe do
          osl_acme_lego_cert 'download-ros' do
            domains %w(download.ros.osuosl.org download.ros.org)
          end
        end

        before do
          allow(File).to receive(:exist?).with(crt).and_return(false)
        end

        it do
          is_expected.to create_systemd_unit('lego-download-ros.service').with(
            content: <<~EOU
              [Unit]
              Description=Obtain or renew the download-ros Let's Encrypt certificate with lego
              Wants=network-online.target
              After=network-online.target

              [Service]
              Type=oneshot
              EnvironmentFile=/etc/lego/lego.env
              ExecStart=/usr/bin/flock /var/lib/lego/.lock /usr/local/bin/lego run --dns dnsupdate --force-cert-domains --no-random-sleep --key-type rsa2048 --cert.name download-ros -d download.ros.osuosl.org -d download.ros.org --dns.propagation.disable-rns
              TimeoutStartSec=30min
            EOU
          )
        end

        it { is_expected.to create_systemd_unit('lego-download-ros.timer') }
        it { is_expected.to enable_systemd_unit('lego-download-ros.timer') }
        it { is_expected.to start_systemd_unit('lego-download-ros.timer') }
        it { is_expected.to_not start_systemd_unit('lego-download-ros.service') }

        it do
          expect(subject.systemd_unit('lego-download-ros.timer').content).to match(/^OnActiveSec=2min\nOnCalendar=daily\nRandomizedDelaySec=1h\nPersistent=true$/)
        end
      end

      context 'with a fixed propagation wait and resolvers' do
        cached(:subject) { chef_run }

        recipe do
          osl_acme_lego_cert 'test' do
            domains %w(test.example.org)
            key_type 'ec256'
            propagation_wait '2s'
            resolvers '127.0.0.2:53'
          end
        end

        it do
          expect(subject.systemd_unit('lego-test.service').content).to include(
            'ExecStart=/usr/bin/flock /var/lib/lego/.lock /usr/local/bin/lego run --dns dnsupdate --force-cert-domains --no-random-sleep --key-type ec256 ' \
            "--cert.name test -d test.example.org --dns.propagation.wait 2s --dns.resolvers 127.0.0.2:53\n"
          )
        end
      end

      context 'publishing' do
        let(:pair) { osl_acme_test_pair('download.ros.org') }
        let(:issuer) { osl_acme_test_pair('Test Issuer').first }
        let(:item) { instance_double(Chef::DataBagItem, data_bag: nil, 'raw_data=': nil) }
        let(:issuer_file) { '/var/lib/lego/certificates/download-ros.issuer.crt' }

        recipe do
          osl_acme_lego_cert 'download-ros' do
            action :publish
          end
        end

        before do
          allow(File).to receive(:exist?).with(crt).and_return(true)
          allow(File).to receive(:exist?).with(key).and_return(true)
          allow(File).to receive(:read).with(crt).and_return(pair.first + issuer)
          allow(File).to receive(:read).with(key).and_return(pair[1])
          allow(Chef::EncryptedDataBagItem).to receive(:load_secret).and_return('secret')
          allow(Chef::DataBagItem).to receive(:new).and_return(item)
        end

        context 'a new certificate' do
          before { allow(Chef::DataBagItem).to receive(:load).with('acme_certs', 'download-ros').and_raise(not_found) }

          it 'saves the leaf, chain and key, encrypted, to acme_certs' do
            expect(item).to receive(:data_bag).with('acme_certs')
            expect(item).to receive(:raw_data=) do |data|
              expect(data['cert']).to be_a(Hash)
              plain = Chef::EncryptedDataBagItem.new(data, 'secret')
              expect(plain['id']).to eq 'download-ros'
              expect(plain['cert']).to eq pair.first
              expect(plain['chain']).to eq issuer
              expect(plain['key']).to eq pair[1]
            end
            expect(item).to receive(:save)
            chef_run
          end

          it 'logs no error for the item it is about to create' do
            allow(Chef::Log).to receive(:error).and_call_original
            allow(item).to receive(:save)
            chef_run
            expect(Chef::Log).to_not have_received(:error).with(/Failed to load data bag item/)
          end
        end

        context 'a renewed certificate' do
          before { allow(Chef::DataBagItem).to receive(:load).and_return(encrypted_item.call('id' => 'download-ros', 'cert' => 'old', 'chain' => issuer)) }

          it do
            expect(item).to receive(:save)
            chef_run
          end
        end

        context 'a changed chain with the same leaf' do
          before { allow(Chef::DataBagItem).to receive(:load).and_return(encrypted_item.call('id' => 'download-ros', 'cert' => pair.first, 'chain' => 'old')) }

          it do
            expect(item).to receive(:save)
            chef_run
          end
        end

        context 'an unchanged certificate' do
          before { allow(Chef::DataBagItem).to receive(:load).and_return(encrypted_item.call('id' => 'download-ros', 'cert' => pair.first, 'chain' => issuer)) }

          it do
            expect(item).to_not receive(:save)
            chef_run
          end
        end

        context 'an unchanged plain item' do
          before { allow(Chef::DataBagItem).to receive(:load).and_return(bag_item.new({ 'id' => 'download-ros', 'cert' => pair.first, 'chain' => issuer })) }

          it do
            expect(item).to_not receive(:save)
            chef_run
          end
        end

        context 'a published item that no longer decrypts' do
          before do
            allow(Chef::DataBagItem).to receive(:load).and_return(encrypted_item.call({ 'id' => 'download-ros', 'cert' => pair.first }, 'old-secret'))
          end

          it do
            expect(item).to receive(:save)
            chef_run
          end
        end

        context 'an unbundled certificate' do
          before do
            allow(File).to receive(:read).with(crt).and_return(pair.first)
            allow(File).to receive(:exist?).with(issuer_file).and_return(true)
            allow(Chef::DataBagItem).to receive(:load).with('acme_certs', 'download-ros').and_raise(not_found)
          end

          it 'takes the chain from issuer.crt' do
            allow(File).to receive(:read).with(issuer_file).and_return(issuer)
            expect(item).to receive(:raw_data=) { |data| expect(Chef::EncryptedDataBagItem.new(data, 'secret')['chain']).to eq issuer }
            expect(item).to receive(:save)
            chef_run
          end

          it 'ignores an issuer.crt that does not parse' do
            allow(File).to receive(:read).with(issuer_file).and_return('-----BEGIN CERTIFICATE-----\njunk')
            expect(item).to receive(:raw_data=) { |data| expect(Chef::EncryptedDataBagItem.new(data, 'secret')['chain']).to eq '' }
            expect(item).to receive(:save)
            chef_run
          end
        end

        context 'a certificate whose key is still being written' do
          before do
            allow(File).to receive(:read).with(key).and_return(osl_acme_test_pair[1])
            allow(Chef::DataBagItem).to receive(:load).with('acme_certs', 'download-ros').and_raise(not_found)
          end

          it do
            expect(item).to_not receive(:save)
            chef_run
          end
        end

        context 'no certificate yet' do
          before { allow(File).to receive(:exist?).with(crt).and_return(false) }

          it do
            expect(item).to_not receive(:save)
            chef_run
          end
        end

        context 'when the server errors reading the item' do
          before do
            allow(Chef::DataBagItem).to receive(:load).and_raise(
              Net::HTTPClientException.new('500 "Internal Server Error"', Net::HTTPResponse.new('1.1', '500', 'Internal Server Error'))
            )
          end

          it { expect { chef_run }.to raise_error(Net::HTTPClientException) }
        end

        context 'metrics' do
          let(:prom) { '/var/lib/node_exporter/acme_cert_download-ros.prom' }

          before do
            allow(File).to receive(:directory?).with('/var/lib/node_exporter').and_return(true)
            allow(File).to receive(:exist?).with(prom).and_return(false)
            allow(File).to receive(:write).and_call_original
            allow(File).to receive(:write).with("#{prom}.tmp", anything)
            allow(File).to receive(:rename).and_call_original
            allow(File).to receive(:rename).with("#{prom}.tmp", prom)
            allow(Chef::DataBagItem).to receive(:load).with('acme_certs', 'download-ros').and_raise(not_found)
            allow(item).to receive(:save)
          end

          it 'ends a publish at published 1 with both dates' do
            chef_run
            expect(File).to have_received(:write).with(
              "#{prom}.tmp",
              /acme_cert_published\{cert="download-ros"\} 1\n.*acme_cert_not_after_seconds\{cert="download-ros"\} \d+\n.*acme_cert_not_before_seconds\{cert="download-ros"\} \d+\n/m
            )
          end

          it 'reports a key that does not match yet as issued, not published' do
            allow(File).to receive(:read).with(key).and_return(osl_acme_test_pair[1])
            chef_run
            expect(File).to have_received(:write).with(
              "#{prom}.tmp",
              /acme_cert_issued\{cert="download-ros"\} 1\n.*acme_cert_published\{cert="download-ros"\} 0\n.*acme_cert_not_before_seconds/m
            )
          end

          it 'reports a half-written certificate without dates' do
            allow(File).to receive(:read).with(crt).and_return("-----BEGIN CERTIFICATE-----\njunk")
            chef_run
            expect(File).to have_received(:write).with(
              "#{prom}.tmp",
              satisfy { |c| c.include?('acme_cert_published{cert="download-ros"} 0') && !c.include?('not_after') }
            )
          end
        end

        %w(403 404).each do |code|
          context "when saving gets a #{code}" do
            before do
              allow(Chef::DataBagItem).to receive(:load).with('acme_certs', 'download-ros').and_raise(not_found)
              allow(item).to receive(:save).and_raise(
                Net::HTTPClientException.new("#{code} \"Error\"", Net::HTTPResponse.new('1.1', code, 'Error'))
              )
            end

            it { expect { chef_run }.to raise_error(/HTTP #{code}.*knife acl add client .* data acme_certs create,update/) }
          end
        end
      end

      context 'deleting' do
        cached(:subject) { chef_run }

        recipe do
          osl_acme_lego_cert 'download-ros' do
            action :delete
          end
        end

        it { is_expected.to stop_systemd_unit('lego-download-ros.timer') }
        it { is_expected.to disable_systemd_unit('lego-download-ros.timer') }
        it { is_expected.to delete_systemd_unit('lego-download-ros.timer') }
        it { is_expected.to delete_systemd_unit('lego-download-ros.service') }
        it { is_expected.to delete_file('/var/lib/node_exporter/acme_cert_download-ros.prom') }
      end
    end
  end
end
