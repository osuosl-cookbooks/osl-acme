require_relative '../../spec_helper'

describe 'osl-acme::acme_dns_server' do
  ALL_PLATFORMS.each do |p|
    context "#{p[:platform]} #{p[:version]}" do
      cached(:chef_run) do
        ChefSpec::SoloRunner.new(p).converge(described_recipe)
      end

      before do
        stub_data_bag_item('osl_acme', 'records').and_return(
          id: 'records',
          records: [
            {
              'domain': 'test1.example.org',
            },
            {
              'domain': 'test2.example.org',
              'alt_names': [
                'test2-san1.example.org',
              ],
            },
          ]
        )
        stub_data_bag_item('osl_acme', 'credentials').and_return(
          id: 'credentials',
          credentials: {
            'test1.example.org': {
              'subdomain': 'c8d6aeae-3f21-4786-b243-98bbd7c526a5',
              'username': 'cbfed1bb-c0b9-4b24-b212-5b95caa38f98',
              'key': 'DJ8LgOz83TQM_8GWLyd_IWwwcUk2ehQYLeosCc5K',
            },
            'test2.example.org': {
              'subdomain': '2acca63e-1c34-4860-95f3-ba208dd8b0bc',
              'username': 'c6853765-5036-4f01-9325-c7b97ee0fb2e',
              'key': '0KUj2IPnzndUpZRRbiNFuBTEJ1bnIE768QcyUWWj',
            },
            'test2-san1.example.org': {
              'subdomain': '773aacab-9539-4d59-b5e6-76718261e078',
              'username': '0a59ceba-4648-4b91-b3d0-879160ab5bdf',
              'key': 'sHXgTTZtxKXhnK23XusVRZUbGpvae43cZnjNSn52',
            },
          }
        )
        stub_data_bag_item('osl_acme', 'database').and_return(id: 'database', host: '127.0.0.1', user: 'testuser', pass: 'testpass', dbname: 'testdb')
      end

      it 'converges successfully' do
        expect { chef_run }.to_not raise_error
      end
      it do
        expect(chef_run).to create_directory('/etc/acme-dns').with(recursive: true)
      end
      it do
        expect(chef_run).to create_remote_file("#{Chef::Config[:file_cache_path]}/acme-dns.tar.gz")
          .with(
            source: 'https://github.com/joohoi/acme-dns/releases/download/v0.8/acme-dns_0.8_linux_amd64.tar.gz',
            checksum: 'f5c031a78ea867a40c3b7cdb1d370f423bdf923e79a9607e44dabdc4dbda6a05',
            mode: '0755'
          )
      end
      it do
        expect(chef_run.remote_file("#{Chef::Config[:file_cache_path]}/acme-dns.tar.gz")).to notify("archive_file[#{Chef::Config[:file_cache_path]}/acme-dns.tar.gz]").to(:extract).immediately
      end
      it do
        expect(chef_run).to nothing_archive_file("#{Chef::Config[:file_cache_path]}/acme-dns.tar.gz")
          .with(
            destination: '/etc/acme-dns',
            overwrite: true
          )
      end
      it do
        expect(chef_run.archive_file("#{Chef::Config[:file_cache_path]}/acme-dns.tar.gz")).to notify('link[/usr/local/bin/acme-dns]').to(:create).immediately
      end
      it do
        expect(chef_run).to nothing_link('/usr/local/bin/acme-dns').with(to: '/etc/acme-dns/acme-dns')
      end
      it do
        expect(chef_run).to create_template('/etc/acme-dns/config.cfg')
          .with(
            source: 'config.cfg.erb',
            variables: {
              dns_interface: '0.0.0.0',
              pg_host: '127.0.0.1',
              pg_user: 'testuser',
              pg_pass: 'testpass',
              pg_dbname: 'testdb',
            }
          )
      end
      it do
        expect(chef_run.template('/etc/acme-dns/config.cfg')).to notify('systemd_unit[acme-dns.service]').to(:restart)
      end
      it do
        expect(chef_run).to create_systemd_unit('acme-dns.service')
      end
      it do
        expect(chef_run).to enable_systemd_unit('acme-dns.service')
      end
      it do
        expect(chef_run).to start_systemd_unit('acme-dns.service')
      end
    end
  end
end
