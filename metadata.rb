name             'osl-acme'
maintainer       'Oregon State University'
maintainer_email 'chef@osuosl.org'
license          'Apache-2.0'
chef_version     '>= 14.0' if respond_to?(:chef_version)
issues_url       'https://github.com/osuosl-cookbooks/osl-acme/issues'
source_url       'https://github.com/osuosl-cookbooks/osl-acme'
description      'Installs/Configures osl-acme'
long_description 'Installs/Configures osl-acme'
version          '3.0.0'

depends          'acme', '~> 4.1.1'
depends          'git'
depends          'resolver'

supports         'centos', '~> 6.0'
supports         'centos', '~> 7.0'
