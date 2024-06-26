describe command('curl https://foo.org -k -v') do
  its('stderr') { should match /issuer: CN=Pebble Intermediate CA/ }
  its('stderr') { should match /subject: CN=foo\.org/ }
end
