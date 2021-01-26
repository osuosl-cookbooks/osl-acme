chef_gem 'acme-client' do
  compile_time true
end
gem_package 'acme-client' do
  compile_time true
end

get_acme_cert 'test.dassonville.dev'
