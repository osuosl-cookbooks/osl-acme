osl-acme Cookbook
=================

OSL wrapper cookbook for ACME (Let's Encrypt), built on the
[acme](https://supermarket.chef.io/cookbooks/acme) cookbook.

Requirements
------------

- Cinc Client 16 or later
- AlmaLinux 8, 9 and 10

Usage
-----

#### osl-acme::default

Includes the acme cookbook's default recipe and sets the contact address to
`letsencrypt@osuosl.org` and renewal to 32 days before expiry. Callers then use
`acme_certificate` for HTTP-01 certificates.

#### osl-acme::server

Installs and starts [Pebble](https://github.com/letsencrypt/pebble), Let's
Encrypt's small test CA, with dnsmasq resolving the names in
`node['osl-acme']['pebble']['host_aliases']` to the node. Other cookbooks' test
suites include it to issue certificates in kitchen.

  NOTE: This recipe should NEVER be used in production. It adds Pebble's test
  CA to the Cinc trust store.

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
