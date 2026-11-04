resource_name :osl_acme_lego_cert
provides :osl_acme_lego_cert
default_action :create
unified_mode true

property :cert_name, String, name_property: true
property :domains, Array, required: [:create]
property :key_type, String, default: 'rsa2048'
property :data_bag, String, default: 'acme_certs'
property :propagation_wait, String
property :resolvers, [String, Array], default: []

action_class do
  def service_unit
    "lego-#{new_resource.cert_name}.service"
  end

  def timer_unit
    "lego-#{new_resource.cert_name}.timer"
  end

  def lego_file(ext)
    ::File.join(osl_acme_lego_path, 'certificates', "#{new_resource.cert_name}.#{ext}")
  end

  # Not data_bag_item, which logs an ERROR for the 404 every new certificate starts with
  def current_item
    item = Chef::DataBagItem.load(new_resource.data_bag, new_resource.cert_name) # rubocop:disable Chef/Modernize/DatabagHelpers
    encrypted?(item.raw_data) ? Chef::EncryptedDataBagItem.new(item.raw_data, Chef::EncryptedDataBagItem.load_secret) : item
  rescue Net::HTTPClientException => e
    raise unless e.response.code == '404'
    nil
  end

  def save_item(leaf, chain, key)
    item = Chef::DataBagItem.new
    item.data_bag(new_resource.data_bag)
    item.raw_data = Chef::EncryptedDataBagItem.encrypt_data_bag_item(
      { 'id' => new_resource.cert_name, 'cert' => leaf, 'chain' => chain, 'key' => key },
      Chef::EncryptedDataBagItem.load_secret
    )
    item.save
  rescue Net::HTTPClientException => e
    raise unless %w(403 404).include?(e.response.code)
    raise "Can't write data bag item #{new_resource.data_bag}/#{new_resource.cert_name} (HTTP #{e.response.code}): " \
          "create the bag and run `knife acl add client #{node.name} data #{new_resource.data_bag} create,update`"
  end

  # Fallback for an unbundled .crt; only a file that parses is used
  def issuer_chain
    return '' unless ::File.exist?(lego_file('issuer.crt'))
    issuer = ::File.read(lego_file('issuer.crt'))
    osl_acme_split_pem(issuer) ? issuer : ''
  end

  # An item that won't decrypt (a rotated secret) counts as stale and gets republished
  def item_in_sync?(leaf, chain)
    current = current_item
    !current.nil? && current['cert'] == leaf && current['chain'] == chain
  rescue Chef::EncryptedDataBagItem::DecryptionFailure, Chef::EncryptedDataBagItem::UnacceptableEncryptedDataBagItemFormat
    false
  end

  def write_metrics(issued:, published:, leaf: nil)
    dates = leaf ? { not_after: osl_acme_not_after(leaf), not_before: osl_acme_not_before(leaf) } : {}
    osl_acme_write_metrics(
      new_resource.cert_name,
      osl_acme_metrics_content(cert_name: new_resource.cert_name, issued: issued, published: published, **dates)
    )
  end

  def publish
    issued = ::File.exist?(lego_file('crt')) && ::File.exist?(lego_file('key'))
    return write_metrics(issued: false, published: false) unless issued

    leaf, chain = osl_acme_split_pem(::File.read(lego_file('crt')))
    key = ::File.read(lego_file('key'))
    # lego writes .crt then .key, so a converge during a renewal can see a new cert with the old key
    unless leaf && osl_acme_key_matches?(leaf, key)
      Chef::Log.warn("lego's #{new_resource.cert_name} certificate and key don't match yet; publishing next run")
      return write_metrics(issued: true, published: false, leaf: leaf)
    end
    chain = issuer_chain if chain.empty?

    in_sync = item_in_sync?(leaf, chain)
    write_metrics(issued: true, published: in_sync, leaf: leaf)
    return if in_sync

    converge_by("publish #{new_resource.cert_name} to data bag #{new_resource.data_bag}") do
      save_item(leaf, chain, key)
    end
    write_metrics(issued: true, published: true, leaf: leaf)
  end
end

action :create do
  # flock: every certificate shares one lego account, which lego creates without a lock
  systemd_unit service_unit do
    content <<~EOU
      [Unit]
      Description=Obtain or renew the #{new_resource.cert_name} Let's Encrypt certificate with lego
      Wants=network-online.target
      After=network-online.target

      [Service]
      Type=oneshot
      EnvironmentFile=#{osl_acme_lego_env}
      ExecStart=/usr/bin/flock #{osl_acme_lego_path}/.lock #{osl_acme_lego_command(
        cert_name: new_resource.cert_name,
        domains: new_resource.domains,
        key_type: new_resource.key_type,
        propagation_wait: new_resource.propagation_wait,
        resolvers: new_resource.resolvers
      )}
      TimeoutStartSec=30min
    EOU
    action :create
  end

  systemd_unit timer_unit do
    content <<~EOU
      [Unit]
      Description=Daily lego run for the #{new_resource.cert_name} certificate

      [Timer]
      OnActiveSec=2min
      OnCalendar=daily
      RandomizedDelaySec=1h
      Persistent=true

      [Install]
      WantedBy=timers.target
    EOU
    action [:create, :enable, :start]
  end

  publish
end

action :publish do
  publish
end

action :delete do
  systemd_unit timer_unit do
    action [:stop, :disable, :delete]
  end

  systemd_unit service_unit do
    action :delete
  end

  file ::File.join(OslAcme::Cookbook::Helpers::NODE_EXPORTER_DIR, "acme_cert_#{new_resource.cert_name}.prom") do
    action :delete
  end
end
