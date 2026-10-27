# Reads the item osl_acme_lego_cert published, the way osl-mirror will on the ftp nodes
certificate_manage 'test-example' do
  data_bag 'acme_certs'
  cert_file 'acme-test-example.pem'
  key_file 'acme-test-example.key'
  chain_file 'acme-test-example-bundle.crt'
end
