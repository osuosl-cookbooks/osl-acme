describe port('192.168.10.1', 53) do
  it { should be_listening }
end

describe file('/etc/pki/tls/test1.example.org.pem') do
  it { should exist }
end

describe file('/etc/pki/tls/test2.example.org.pem') do
  it { should exist }
end

describe x509_certificate('/etc/pki/tls/test1.example.org.pem') do
  its('validity_in_days') { should be > 30 }

  its('subject.CN') { should eq 'test1.example.org' }
  its('issuer.CN') { should include 'Pebble Intermediate CA' }

  its('extensions') { should include 'subjectAltName' }
  its('extensions.subjectAltName') { should include 'DNS:test1.example.org' }
end

describe x509_certificate('/etc/pki/tls/test2.example.org.pem') do
  its('validity_in_days') { should be > 30 }

  its('subject.CN') { should eq 'test2.example.org' }
  its('issuer.CN') { should include 'Pebble Intermediate CA' }

  its('extensions') { should include 'subjectAltName' }
  its('extensions.subjectAltName') { should include 'DNS:test2.example.org' }
  its('extensions.subjectAltName') { should include 'DNS:test2-san1.example.org' }
  its('extensions.subjectAltName') { should include 'DNS:test2-san2.example.org' }
end
