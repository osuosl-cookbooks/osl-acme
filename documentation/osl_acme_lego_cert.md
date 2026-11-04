# osl_acme_lego_cert

Issues and renews one Let's Encrypt certificate with lego over DNS-01, and
publishes it to an encrypted data bag item so the nodes that serve those names
can read it with `certificate_manage`. It's meant for names served by more than
one node, where HTTP-01 can't work: the ftp mirror vhosts, and later the load
balancers and the `*.osuosl.org` wildcard. It needs `osl_acme_lego` declared
first on the same node.

Chef never runs lego itself, so a missing CNAME or a Let's Encrypt outage can't
fail a converge:

- `lego-<name>.service` is a oneshot running `lego run`. That obtains a
  certificate when none is stored and otherwise renews when Let's Encrypt's
  renewal window opens (about a third of the lifetime before expiry).
  `--force-cert-domains` makes `domains` authoritative: a changed list, a name
  added or dropped, gets a new certificate on the next run of the service,
  without waiting for the renewal window. A changed `key_type` waits for the
  next renewal.
- The service runs lego under `flock /var/lib/lego/.lock`, so certificates on
  one node never run lego at the same time. They share one Let's Encrypt
  account, which lego creates without a lock on its first run.
- `lego-<name>.timer` runs it daily. The first run comes within about an hour
  of the converge that creates the timer: systemd applies the hour of random
  delay to the two-minute start delay too. `systemctl start lego-<name>.service`
  runs it now.

Each name needs a static CNAME in zonefiles before the first issue, with a
target of its own (lego replaces the whole TXT record set):

```text
_acme-challenge.download.ros.org.  CNAME  download-ros-org.acme.osuosl.org.
```

## Publishing

On every converge (and with `:publish`) the resource compares lego's
certificate in `/var/lib/lego/certificates/<name>.crt` with the data bag item
`<data_bag>/<name>`, and saves `{id, cert, chain, key}`, encrypted with the
node's secret, when the leaf or the chain differs. It skips the publish when
the key on disk doesn't match the certificate yet (lego writes them one after
another during a renewal); the next converge picks it up.

The node needs `create` and `update` on the bag. The bag isn't in the data_bags
repo, and its Jenkinsfile leaves it out of `--purge`:

```console
knife data bag create acme_certs
knife acl add client util1.osuosl.org data acme_certs create,update
```

## Metrics

When `/var/lib/node_exporter` exists, the resource writes
`acme_cert_<name>.prom` for node_exporter's textfile collector:

| Metric                         | Meaning                                                     |
|--------------------------------|-------------------------------------------------------------|
| `acme_cert_issued`             | 1 once lego holds a certificate for the name                |
| `acme_cert_published`          | 1 when the data bag item matches lego's certificate         |
| `acme_cert_not_after_seconds`  | Expiry of lego's certificate, as a Unix timestamp           |
| `acme_cert_not_before_seconds` | Start of lego's certificate's validity, as a Unix timestamp |

A name whose CNAME doesn't exist yet stays at `acme_cert_issued 0` while its
timer fails daily, which is expected for a dormant certificate. A certificate
whose key doesn't match yet reads `acme_cert_issued 1` and
`acme_cert_published 0` until it publishes. The two dates let the expiry alert
work from each certificate's own lifetime.

## Actions

- `:create`: Writes the service and timer, starts the timer, and publishes
  (default)
- `:publish`: Publishes only
- `:delete`: Stops and removes the timer and service and deletes the metrics
  file. Dropping the resource from a recipe leaves the units in place, so retire
  a certificate with this action for one release. It leaves lego's files under
  `/var/lib/lego/certificates/` and the data bag item in place; remove the item
  from a workstation with `knife data bag delete <data_bag> <name>`.

## Properties

| Property           | Type          | Default         | Required          | Description                                                        |
|--------------------|---------------|-----------------|-------------------|--------------------------------------------------------------------|
| `cert_name`        | String        | resource name   | no                | lego `--cert.name`, unit names and the data bag item id            |
| `domains`          | Array         |                 | yes, for `:create`| Names on the certificate, as subject alternative names             |
| `key_type`         | String        | `rsa2048`       | no                | lego `--key-type`                                                  |
| `data_bag`         | String        | `acme_certs`    | no                | Bag the certificate is published to                                |
| `propagation_wait` | String        |                 | no                | Fixed wait (`2s`) instead of checking the authoritative servers    |
| `resolvers`        | String, Array | `[]`            | no                | Recursive resolvers lego uses to follow the CNAME                  |

RSA is the default because Let's Encrypt's RSA chain is the short one
(`EE <- YR1 <- Root YR <- ISRG Root X1`), which old clients on the mirrors
handle. `propagation_wait` and `resolvers` exist for the kitchen suite; in
production lego checks the zone's authoritative servers before asking for
validation.

## Examples

```ruby
osl_acme_lego_cert 'download-ros' do
  domains %w(download.ros.osuosl.org download.ros.org)
end

osl_acme_lego_cert 'cinc-wildcard' do
  domains %w(*.cinc.sh cinc.osuosl.org)
end
```

Reading the published certificate on a consumer:

```ruby
certificate_manage 'download-ros' do
  data_bag 'acme_certs'
  cert_file 'acme-download-ros.pem'
  key_file 'acme-download-ros.key'
  chain_file 'acme-download-ros-bundle.crt'
end
```
