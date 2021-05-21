default['osl-acme']['pebble']['version'] = 'v2.3.1'
default['osl-acme']['pebble']['checksum'] = '60a401159d5132411c88e93ff03ba3322d4ecc7fdba78503da552018f3f98230'
default['osl-acme']['pebble']['host_aliases'] = []
default['osl-acme']['pebble']['always_valid'] = true
default['osl-acme']['pebble']['command'] = '/usr/local/bin/pebble -config /opt/pebble/test/config/pebble-config.json'

default['osl-acme']['acme-dns']['version'] = 'latest' # latest version isn't tagged
default['osl-acme']['acme-dns']['api'] = 'http://192.168.10.1'
default['osl-acme']['acme-dns']['domain'] = 'acme-dns.example.org'
default['osl-acme']['acme-dns']['nsname'] = 'ns.acme-dns.example.org'
default['osl-acme']['acme-dns']['nsadmin'] = 'test.example.org'

default['acme']['dir'] = 'https://acme-staging-v02.api.letsencrypt.org/directory'
