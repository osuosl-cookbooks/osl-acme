bind_service 'default' do
  action [:create, :start]
end

cookbook_file '/etc/named.conf'

directory '/var/named/master' do
  recursive true
end

cookbook_file '/var/named/master/db.example.org' do
  notifies :restart, 'bind_service[default]', :immediately
end
