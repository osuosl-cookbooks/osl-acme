describe command('/usr/local/bin/lego --version') do
  its('exit_status') { should eq 0 }
  its('stdout') { should match(/5\.5\.2/) }
end

describe file('/etc/lego/lego.env') do
  its('mode') { should cmp '0600' }
  its('content') { should match(/^DNSUPDATE_ZONES=acme\.example\.org$/) }
  its('content') { should match(%r{^DNSUPDATE_TSIG_FILE=/etc/named/acme-tsig\.key$}) }
  its('content') { should match(%r{^LEGO_SERVER=https://127\.0\.0\.1:14000/dir$}) }
end

describe systemd_service('lego-test-example.timer') do
  it { should be_enabled }
  it { should be_running }
end

describe file('/etc/systemd/system/lego-test-example.service') do
  its('content') { should match(%r{^EnvironmentFile=/etc/lego/lego\.env$}) }
  its('content') { should match(%r{^ExecStart=/usr/bin/flock /var/lib/lego/\.lock /usr/local/bin/lego run }) }
  its('content') { should match(/--key-type rsa2048 --cert\.name test-example -d test\.example\.org -d www\.example\.org/) }
  its('content') { should match(/--dns\.propagation\.wait 2s --dns\.resolvers 127\.0\.0\.2:53$/) }
end

describe x509_certificate('/var/lib/lego/certificates/test-example.crt') do
  its('subject_alt_names') { should include 'DNS:test.example.org' }
  its('subject_alt_names') { should include 'DNS:www.example.org' }
  its('issuer.CN') { should match(/Pebble/) }
  its('key_length') { should eq 2048 }
end

# The item osl_acme_lego_cert published, read back by certificate_manage in the second recipe
describe x509_certificate('/etc/pki/tls/certs/acme-test-example.pem') do
  its('subject_alt_names') { should include 'DNS:test.example.org' }
  its('subject_alt_names') { should include 'DNS:www.example.org' }
end

describe command(
  'bash -c "diff <(openssl x509 -noout -serial -in /var/lib/lego/certificates/test-example.crt) ' \
  '<(openssl x509 -noout -serial -in /etc/pki/tls/certs/acme-test-example.pem)"'
) do
  its('exit_status') { should eq 0 }
end

describe file('/etc/pki/tls/certs/acme-test-example-bundle.crt') do
  its('content') { should match(/BEGIN CERTIFICATE/) }
end

describe file('/var/lib/node_exporter/acme_cert_test-example.prom') do
  its('content') { should match(/^acme_cert_issued\{cert="test-example"\} 1$/) }
  its('content') { should match(/^acme_cert_published\{cert="test-example"\} 1$/) }
  its('content') { should match(/^acme_cert_not_after_seconds\{cert="test-example"\} \d+$/) }
  its('content') { should match(/^acme_cert_not_before_seconds\{cert="test-example"\} \d+$/) }
end
