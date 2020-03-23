common_name = os.release.to_i < 8 ? /common name: foo\.org/ : /subject: CN=foo\.org/

describe command('curl https://foo.org -k -v') do
  its('stderr') { should match /issuer: CN=Pebble Intermediate CA/ }
  its('stderr') { should match common_name }
end
