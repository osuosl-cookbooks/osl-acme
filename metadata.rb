name             'osl-acme'
maintainer       'Oregon State University'
maintainer_email 'chef@osuosl.org'
license          'Apache-2.0'
chef_version     '>= 14.0'
issues_url       'https://github.com/osuosl-cookbooks/osl-acme/issues'
source_url       'https://github.com/osuosl-cookbooks/osl-acme'
description      'Installs/Configures osl-acme'
version          '3.2.0'

depends          'acme', '~> 4.1.2'
depends          'osl-git'
depends          'resolver'

supports         'centos', '~> 7.0'
supports         'centos', '~> 8.0'
