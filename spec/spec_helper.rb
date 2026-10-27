require 'chefspec'
require 'chefspec/berkshelf'

ALMA_10 = {
  platform: 'almalinux',
  version: '10',
}.freeze

ALMA_9 = {
  platform: 'almalinux',
  version: '9',
}.freeze

ALMA_8 = {
  platform: 'almalinux',
  version: '8',
}.freeze

ALL_PLATFORMS = [
  ALMA_10,
  ALMA_9,
  ALMA_8,
].freeze

RSpec.configure do |config|
  config.log_level = :warn
  config.file_cache_path = '/var/chef/cache'
end

# A self-signed certificate and its key, for the publish and helper specs
def osl_acme_test_pair(cn = 'test.example.org')
  key = OpenSSL::PKey::RSA.new(2048)
  cert = OpenSSL::X509::Certificate.new
  cert.version = 2
  cert.serial = rand(1..2**32)
  cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=#{cn}")
  cert.public_key = key.public_key
  cert.not_before = Time.now
  cert.not_after = Time.now + 86_400
  cert.sign(key, OpenSSL::Digest.new('SHA256'))
  [cert.to_pem, key.to_pem]
end
