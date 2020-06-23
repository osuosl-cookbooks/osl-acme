require_relative '../../spec_helper'

describe 'osl-acme::server' do
  ALL_PLATFORMS.each do |p|
    context "#{p[:platform]} #{p[:version]}" do
      cached(:chef_run) do
        ChefSpec::SoloRunner.new(p) do |node|
          node.automatic['chef_packages']['chef']['version'] = '14.15.6'
          node.normal['osl-acme']['pebble']['host_aliases'] = %w(example.com foo.org)
        end.converge(described_recipe)
      end
      it 'converges successfully' do
        expect { chef_run }.to_not raise_error
      end
      it do
        expect(chef_run).to install_package('dnsmasq')
      end
      it do
        expect(chef_run).to create_template('/etc/dnsmasq.conf').with(source: 'dnsmasq.erb')
      end
      %w(example.com foo.org).each do |host|
        it do
          expect(chef_run).to render_file('/etc/dnsmasq.conf').with_content(%r{^address=/#{host}/10.0.0.2$})
        end
      end
      it do
        expect(chef_run.template('/etc/dnsmasq.conf')).to notify('service[dnsmasq]').to(:restart).immediately
      end
      it do
        expect(chef_run).to start_service('dnsmasq')
      end
      it do
        expect(chef_run).to enable_service('dnsmasq')
      end
      it do
        expect(chef_run).to create_remote_file('/usr/local/bin/pebble')
          .with(
            source: 'http://packages.osuosl.org/distfiles/pebble-v1.0.1',
            checksum: '902e061d9c563d8cbf9a56b2c299898f99a0da4ec3a8d8d7ef5d5e68de9cdb39',
            mode: '0755'
          )
      end
      it do
        expect(chef_run).to create_user('pebble').with(system: true)
      end
      it do
        expect(chef_run).to create_directory('/opt/pebble').with(user: 'pebble')
      end
      it do
        expect(chef_run).to sync_git('/opt/pebble')
          .with(
            user: 'pebble',
            repository: 'https://github.com/letsencrypt/pebble.git',
            depth: 1,
            revision: 'v1.0.1'
          )
      end
      it do
        expect(chef_run).to run_bash('update Chef trusted certificates store')
          .with(
            code: 'cat /opt/pebble/test/certs/pebble.minica.pem >> /opt/chef/embedded/ssl/certs/cacert.pem; touch /opt/chef/embedded/ssl/certs/PEBBLE-MINICA-IS-INSTALLED',
            creates: '/opt/chef/embedded/ssl/certs/PEBBLE-MINICA-IS-INSTALLED'
          )
      end
      context 'Cinc 15' do
        cached(:chef_run) do
          ChefSpec::SoloRunner.new(p) do |node|
            node.automatic['chef_packages']['chef']['version'] = '15.11.3'
          end.converge(described_recipe)
        end
        it 'converges successfully' do
          expect { chef_run }.to_not raise_error
        end
        it do
          expect(chef_run).to run_bash('update Chef trusted certificates store')
            .with(
              code: 'cat /opt/pebble/test/certs/pebble.minica.pem >> /opt/cinc/embedded/ssl/certs/cacert.pem; touch /opt/cinc/embedded/ssl/certs/PEBBLE-MINICA-IS-INSTALLED',
              creates: '/opt/cinc/embedded/ssl/certs/PEBBLE-MINICA-IS-INSTALLED'
            )
        end
      end

      it do
        expect(chef_run).to create_systemd_unit('pebble.service')
          .with(
            content: "[Unit]\nDescription=Pebble is a small RFC 8555 ACME test server\nAfter=network.target\n[Service]\nWorkingDirectory=/opt/pebble\nUser=pebble\nEnvironment=PEBBLE_VA_ALWAYS_VALID=1\nEnvironment=PEBBLE_VA_NOSLEEP=1\nEnvironment=PEBBLE_WFE_NONCEREJECT=0\nExecStart=/usr/local/bin/pebble -config /opt/pebble/test/config/pebble-config.json\n[Install]\nWantedBy=multi-user.target\n"
          )
      end
      it do
        expect(chef_run).to enable_systemd_unit('pebble.service')
      end
      it do
        expect(chef_run).to start_systemd_unit('pebble.service')
      end
    end
  end
end
