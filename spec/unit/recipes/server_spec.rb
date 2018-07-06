require_relative '../../spec_helper'

describe 'osl-acme::server' do
  ALL_PLATFORMS.each do |p|
    context "#{p[:platform]} #{p[:version]}" do
      cached(:chef_run) do
        ChefSpec::SoloRunner.new(p).converge(described_recipe)
      end
      before do
        stub_command('/usr/local/bin/docker-compose ps -q | wc -l | grep 0').and_return(true)
        stub_command('/usr/local/go/bin/go version | grep "go1.8 "')
        stub_command('screen -list boulder | /bin/grep 1\ Socket\ in')
      end
      it 'converges successfully' do
        expect { chef_run }.to_not raise_error
      end
    end
  end
end
