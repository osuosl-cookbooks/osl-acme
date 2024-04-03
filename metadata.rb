name             'osl-acme'
maintainer       'Oregon State University'
maintainer_email 'chef@osuosl.org'
license          'Apache-2.0'
chef_version     '>= 16.0'
issues_url       'https://github.com/osuosl-cookbooks/osl-acme/issues'
source_url       'https://github.com/osuosl-cookbooks/osl-acme'
description      'Installs/Configures osl-acme'
version          '4.2.2'

depends          'acme', '~> 4.1.4'
depends          'osl-firewall'
depends          'osl-git'
depends          'osl-selinux'
depends          'resolver', '~> 4.0.2'

supports         'almalinux', '~> 8.0'
supports         'centos', '~> 7.0'
