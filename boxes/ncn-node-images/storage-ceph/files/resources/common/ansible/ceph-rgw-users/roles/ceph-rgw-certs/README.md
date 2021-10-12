Host Certificate
----

A host certificate is created in the `host_certificate_crt` file (which defaults
to `/var/opt/cray/certificate_authority/hosts/host.crt`).
The host certificate is created with several SAN (Subject Alternative Name, see
https://tools.ietf.org/html/rfc5280#section-4.2.1.6) values:

- The FQDN for all of the hosts in the `storage` group from the ansible
  inventory.
- All of the items in the `host_certificate_extra_altnames`
  configuration option. This variable is defined in
  `roles/ceph-rgw-certs/defaults/main.yml` and can be overridden in the
  Ansible inventory.
