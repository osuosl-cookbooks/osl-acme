default['osl-acme']['pebble']['version'] = 'v1.0.1'
default['osl-acme']['pebble']['host_aliases'] = []
default['osl-acme']['pebble']['systemd'] = <<-EOF.gsub(/^\s+/, '')
  [Unit]
  Description=Pebble is a small RFC 8555 ACME test server
  After=network.target

  [Service]
  WorkingDirectory=/opt/pebble
  User=pebble
  Environment=PEBBLE_VA_ALWAYS_VALID=0
  Environment=PEBBLE_VA_NOSLEEP=1
  Environment=PEBBLE_WFE_NONCEREJECT=0
  ExecStart=/usr/local/bin/pebble -config /opt/pebble/test/config/pebble-config.json -dnsserver :8053

  [Install]
  WantedBy=multi-user.target
EOF

default['osl-acme']['acme-dns']['api'] = 'http://192.168.10.1'
default['osl-acme']['acme-dns']['domain'] = 'acme-dns.example.org'
default['osl-acme']['acme-dns']['nsname'] = 'ns.acme-dns.example.org'
default['osl-acme']['acme-dns']['nsadmin'] = 'test.example.org'

default['acme']['dir'] = 'https://acme-staging-v02.api.letsencrypt.org/directory'
