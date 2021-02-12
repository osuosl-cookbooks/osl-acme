chef_gem 'acme-client' do
  compile_time true
end

records = data_bag_item('osl_acme', 'records')['records']

records.each do |record|
  get_acme_cert record['domain'] do
    contact 'mailto:andrew@dassonville.dev'
    acme_directory 'https://acme-staging-v02.api.letsencrypt.org/directory'
    acme_dns_api 'http://ns.acme-dns1.dassonville.dev'
    acme_dns_api_subdomain record['subdomain']
    acme_dns_api_username record['username']
    acme_dns_api_key record['key']
    cert_path "/tmp/#{record['domain']}-test.pem"
  end
end
