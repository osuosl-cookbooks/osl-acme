# :create ran on the first converge, so everything below existed before :delete
describe file('/var/tmp/lego-delete-created') do
  it { should exist }
end

%w(service timer).each do |unit|
  describe file("/etc/systemd/system/lego-delete-example.#{unit}") do
    it { should_not exist }
  end
end

describe systemd_service('lego-delete-example.timer') do
  it { should_not be_running }
  it { should_not be_enabled }
end

describe file('/var/lib/node_exporter/acme_cert_delete-example.prom') do
  it { should_not exist }
end
