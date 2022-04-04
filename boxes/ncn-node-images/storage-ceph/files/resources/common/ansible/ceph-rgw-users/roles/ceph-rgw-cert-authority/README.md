Certificate Authority
----

A certificate authority (CA) is set up on the "first" storage node in the
`cray_ca_root_dir` directory (which defaults to
`/var/opt/cray/certificate_authority`).
A CA certificate is created in the `cray_ca_root_crt` file
(which defaults to
`/var/opt/cray/certificate_authority/certificate_authority.crt`).
The CA certificate is copied to all of the management hosts to
`/usr/share/pki/trust/anchors/certificate_authority.crt`.
