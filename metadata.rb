name             'osl-acme'
maintainer       'Oregon State University'
maintainer_email 'chef@osuosl.org'
license          'Apache-2.0'
chef_version     '>= 14.0'
issues_url       'https://github.com/osuosl-cookbooks/osl-acme/issues'
source_url       'https://github.com/osuosl-cookbooks/osl-acme'
description      'Installs/Configures osl-acme'
long_description 'Installs/Configures osl-acme'
version          '3.0.1'

depends          'acme', '~> 4.1.1'
depends          'git'
depends          'resolver'

# TODO: DO NOT BUMP ON production_centos6 and phpbb until migration
supports         'centos', '~> 7.0'
supports         'centos', '~> 8.0'
