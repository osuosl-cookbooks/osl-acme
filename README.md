osl-acme Cookbook
=================

OSL wrapper cookbook for ACME (LetsEncrypt) utilizing the
[acme](https://supermarket.chef.io/cookbooks/acme) and
[osl-letsencrypt-boulder-server](https://github.com/osuosl-cookbooks/osl-letsencrypt-boulder-server)
cookbooks.

Requirements
------------

 - Chef 12.18.x and higher

Attributes
----------

Usage
-----
#### osl-acme::default

This includes the default recipe for the acme cookbook and sets the contact
information to our default email.

#### osl-acme::server

This installs and starts [Boulder](https://github.com/letsencrypt/boulder) which
is the CA server behind LetsEncrypt. This allows us to do full test integration
for LetsEncrypt.

  NOTE: This recipe should NEVER be used in production. It is only used for
  testing.

#### osl-acme::acme_dns_server

This installs and starts [acme-dns](https://github.com/joohoi/acme-dns) which
streamlines ACME's DNS challenge process.

Contributing
------------

1. Fork the repository on Github
2. Create a named feature branch (like `username/add_component_x`)
3. Write tests for your change
4. Write your change
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Authors
-------------------
- Author:: Oregon State University <chef@osuosl.org>

```text
Copyright:: 2017, Oregon State University

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
