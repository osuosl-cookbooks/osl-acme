default['osl-acme']['pebble']['version'] = 'v1.0.1'
default['osl-acme']['pebble']['host_aliases'] = []
default['osl-acme']['pebble']['systemd'] = <<-EOF.gsub(/^\s+/, '')
  [Unit]
  Description=Pebble is a small RFC 8555 ACME test server
  After=network.target

  [Service]
  WorkingDirectory=/opt/pebble
  User=pebble
  Environment=PEBBLE_VA_ALWAYS_VALID=1
  Environment=PEBBLE_VA_NOSLEEP=1
  Environment=PEBBLE_WFE_NONCEREJECT=0
  ExecStart=/usr/local/bin/pebble -config /opt/pebble/test/config/pebble-config.json

  [Install]
  WantedBy=multi-user.target
EOF
