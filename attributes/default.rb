default['osl-acme']['pebble']['version'] = 'v2.3.1'
default['osl-acme']['pebble']['checksum'] = '60a401159d5132411c88e93ff03ba3322d4ecc7fdba78503da552018f3f98230'
default['osl-acme']['pebble']['host_aliases'] = []
default['osl-acme']['pebble']['always_valid'] = true
default['osl-acme']['pebble']['command'] = '/usr/local/bin/pebble -config /opt/pebble/test/config/pebble-config.json'

default['osl-acme']['acme-dns']['version'] = '0.8'
default['osl-acme']['acme-dns']['checksum'] = 'f5c031a78ea867a40c3b7cdb1d370f423bdf923e79a9607e44dabdc4dbda6a05'
default['osl-acme']['acme-dns']['api'] = 'http://ns.acme-dns.osuosl.org'
default['osl-acme']['acme-dns']['domain'] = 'acme-dns.osuosl.org'
default['osl-acme']['acme-dns']['nsname'] = 'ns.acme-dns.osuosl.org'
default['osl-acme']['acme-dns']['nsadmin'] = 'webmaster.osuosl.org'
