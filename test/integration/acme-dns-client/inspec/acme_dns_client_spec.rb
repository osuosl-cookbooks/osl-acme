describe file('/tmp/test1.example.org.pem') do
  it { should exist }
end

describe file('/tmp/test2.example.org.pem') do
  it { should exist }
end

describe docker.containers do
  its('names') { should include 'acme-dns.osuosl.org' }
  its('images') { should include 'joohoi/acme-dns:latest' }
end

describe port('192.168.10.1', 53) do
  it { should be_listening }
end
