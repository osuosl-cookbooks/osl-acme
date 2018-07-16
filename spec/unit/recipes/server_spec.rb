require_relative '../../spec_helper'

describe 'osl-acme::server' do
  p = CENTOS_7
  context "#{p[:platform]} #{p[:version]}" do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(p).converge(described_recipe)
    end
    before do
      stub_command('/usr/local/bin/docker-compose ps -q | wc -l | grep 0').and_return(true)
      stub_command('screen -list boulder | /bin/grep 1\ Socket\ in')
    end
    it 'converges successfully' do
      expect { chef_run }.to_not raise_error
    end
  end
end
