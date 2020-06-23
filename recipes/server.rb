#
# Cookbook:: osl-acme
# Recipe:: server
#
# Copyright:: 2017-2020, Oregon State University
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

include_recipe 'resolver'
include_recipe 'git'

remote_file '/usr/local/bin/pebble' do
  source "http://packages.osuosl.org/distfiles/pebble-#{node['osl-acme']['pebble']['version']}"
  checksum '902e061d9c563d8cbf9a56b2c299898f99a0da4ec3a8d8d7ef5d5e68de9cdb39'
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
chef_path = node['chef_packages']['chef']['version'].to_i >= 15 ? 'cinc' : 'chef'
bash 'update Chef trusted certificates store' do
  code "cat /opt/pebble/test/certs/pebble.minica.pem >> /opt/#{chef_path}/embedded/ssl/certs/cacert.pem; touch /opt/#{chef_path}/embedded/ssl/certs/PEBBLE-MINICA-IS-INSTALLED"
  creates "/opt/#{chef_path}/embedded/ssl/certs/PEBBLE-MINICA-IS-INSTALLED"
end

systemd_unit 'pebble.service' do
  content node['osl-acme']['pebble']['systemd']
  action [:create, :enable, :start]
end
