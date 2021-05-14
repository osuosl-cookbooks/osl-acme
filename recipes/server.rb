#
# Cookbook:: osl-acme
# Recipe:: server
#
# Copyright:: 2017-2021, Oregon State University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
node.default['acme']['dir'] = 'https://127.0.0.1:14000/dir'

package 'dnsmasq'

template '/etc/dnsmasq.conf' do
  source 'dnsmasq.erb'
  variables(
    hosts: node['osl-acme']['pebble']['host_aliases']
  )
  notifies :restart, 'service[dnsmasq]', :immediately
end

service 'dnsmasq' do
  action [:start, :enable]
end

node.default['resolver']['domain'] = 'example.org'
node.default['resolver']['search'] = 'example.org'
node.default['resolver']['nameservers'] = %w(127.0.0.1)

include_recipe 'osl-acme::default'
include_recipe 'resolver'
include_recipe 'git'

remote_file '/usr/local/bin/pebble' do
  source "https://github.com/letsencrypt/pebble/releases/download/#{node['osl-acme']['pebble']['version']}/pebble_linux-amd64"
  checksum node['osl-acme']['pebble']['checksum']
  mode '0755'
end

user 'pebble' do
  system true
end

directory '/opt/pebble' do
  user 'pebble'
end

git '/opt/pebble' do
  user 'pebble'
  repository 'https://github.com/letsencrypt/pebble.git'
  depth 1
  revision node['osl-acme']['pebble']['version']
end

# Needed for the acme-client gem to continue connecting to pebble;
# please do NOT do this on production Chef nodes!
chef_path = ::File.exist?('/opt/chef/bin/chef-client') ? 'chef' : 'cinc'
bash 'update Chef trusted certificates store' do
  code "cat /opt/pebble/test/certs/pebble.minica.pem >> /opt/#{chef_path}/embedded/ssl/certs/cacert.pem; touch /opt/#{chef_path}/embedded/ssl/certs/PEBBLE-MINICA-IS-INSTALLED"
  creates "/opt/#{chef_path}/embedded/ssl/certs/PEBBLE-MINICA-IS-INSTALLED"
end

systemd_unit 'pebble.service' do
  content <<-EOF.gsub(/^\s+/, '')
    [Unit]
    Description=Pebble is a small RFC 8555 ACME test server
    After=network.target

    [Service]
    WorkingDirectory=/opt/pebble
    User=pebble
    Environment=PEBBLE_VA_ALWAYS_VALID=#{node['osl-acme']['pebble']['always_valid'] ? '1' : '0'}
    Environment=PEBBLE_VA_NOSLEEP=1
    Environment=PEBBLE_WFE_NONCEREJECT=0
    ExecStart=#{node['osl-acme']['pebble']['command']}

    [Install]
    WantedBy=multi-user.target
  EOF
  action [:create, :enable, :start]
end
