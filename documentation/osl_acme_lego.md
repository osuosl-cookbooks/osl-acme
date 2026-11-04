# osl_acme_lego

Installs [lego](https://go-acme.github.io/lego/) from its upstream release
tarball (it isn't packaged in EPEL) and writes `/etc/lego/lego.env`, the
settings every `osl_acme_lego_cert` unit on the node reads: the ACME account,
the CA, and how to reach the BIND dynamic zone that answers DNS-01 challenges
(osl-dns `dynamic_zones`).

lego's DNS provider is `dnsupdate` (RFC 2136). It follows each name's
`_acme-challenge` CNAME into the dynamic zone and updates it with the TSIG key
in `tsig_file`, which is the same `tsig-keygen` file BIND includes. Certificates
and the account live under `/var/lib/lego` (0700).

Declare it before any `osl_acme_lego_cert`: `systemd_unit` verifies each cert's
unit, and that check fails if `/usr/local/bin/lego` isn't there yet.

Only x86_64 is supported; `checksum` is the amd64 tarball's.

## Actions

- `:create`: Installs lego and writes the shared settings (default)

## Properties

| Property     | Type          | Default                                          | Required | Description                                                    |
|--------------|---------------|--------------------------------------------------|----------|----------------------------------------------------------------|
| `version`    | String        | `5.5.2`                                          | no       | lego release to install under `/opt/lego-<version>`            |
| `checksum`   | String        | sha256 of the 5.5.2 amd64 tarball                | no       | sha256 of `lego_v<version>_linux_amd64.tar.gz`                 |
| `email`      | String        | `letsencrypt@osuosl.org`                         | no       | ACME account contact (`LEGO_EMAIL`)                            |
| `server`     | String        | `https://acme-v02.api.letsencrypt.org/directory` | no       | ACME directory (`LEGO_SERVER`)                                 |
| `nameserver` | String        | `127.0.0.1`                                      | no       | BIND server lego sends updates to (`DNSUPDATE_NAMESERVER`)     |
| `zones`      | String, Array | `acme.osuosl.org`                                | no       | Dynamic zones lego may update (`DNSUPDATE_ZONES`)              |
| `tsig_file`  | String        |                                                  | yes      | `tsig-keygen` key file (`DNSUPDATE_TSIG_FILE`)                 |
| `extra_env`  | Hash          | `{}`                                             | no       | More variables for `lego.env`, such as `LEGO_CA_CERTIFICATES`  |

## Examples

```ruby
osl_acme_lego 'default' do
  tsig_file '/etc/named/acme-tsig.key'
end
```
