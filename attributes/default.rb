default['osl-acme']['pebble']['version'] = 'v2.3.1'
default['osl-acme']['pebble']['checksum'] = '60a401159d5132411c88e93ff03ba3322d4ecc7fdba78503da552018f3f98230'
default['osl-acme']['pebble']['host_aliases'] = []
default['osl-acme']['pebble']['always_valid'] = true
default['osl-acme']['pebble']['command'] = '/usr/local/bin/pebble -config /opt/pebble/test/config/pebble-config.json'

default['osl-acme']['acme-dns']['version'] = '0.8'
default['osl-acme']['acme-dns']['checksum'] = '24860e6f24231c8884e621d089d4f327b608b262bb4958310d2aff9f4a08a703'
default['osl-acme']['acme-dns']['api'] = 'http://192.168.10.1'
default['osl-acme']['acme-dns']['domain'] = 'acme-dns.example.org'
default['osl-acme']['acme-dns']['nsname'] = 'ns.acme-dns.example.org'
default['osl-acme']['acme-dns']['nsadmin'] = 'test.example.org'

default['acme']['dir'] = 'https://acme-staging-v02.api.letsencrypt.org/directory'
