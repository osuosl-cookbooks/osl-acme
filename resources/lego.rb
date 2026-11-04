resource_name :osl_acme_lego
provides :osl_acme_lego
default_action :create
unified_mode true

property :version, String, default: '5.5.2'
property :checksum, String, default: '2a35505089e7772c92e1e9ac144df91151ef2eca8568630db0ff91fca06d9bef'
property :email, String, default: 'letsencrypt@osuosl.org'
property :server, String, default: 'https://acme-v02.api.letsencrypt.org/directory'
property :nameserver, String, default: '127.0.0.1'
property :zones, [String, Array], default: 'acme.osuosl.org'
property :tsig_file, String, required: true
property :extra_env, Hash, default: {}

action :create do
  tarball = ::File.join(Chef::Config[:file_cache_path], "lego_v#{new_resource.version}_linux_amd64.tar.gz")
  install_dir = "/opt/lego-#{new_resource.version}"

  remote_file tarball do
    source "https://github.com/go-acme/lego/releases/download/v#{new_resource.version}/lego_v#{new_resource.version}_linux_amd64.tar.gz"
    checksum new_resource.checksum
  end

  # owner/group left unset: archive_file chowns on every run when either is set
  archive_file tarball do
    destination install_dir
  end

  link '/usr/local/bin/lego' do
    to "#{install_dir}/lego"
  end

  directory '/etc/lego' do
    mode '0700'
  end

  directory osl_acme_lego_path do
    mode '0700'
  end

  file osl_acme_lego_env do
    content osl_acme_lego_env_content(
      email: new_resource.email,
      server: new_resource.server,
      nameserver: new_resource.nameserver,
      zones: new_resource.zones,
      tsig_file: new_resource.tsig_file,
      extra_env: new_resource.extra_env
    )
    mode '0600'
  end
end
