#!/usr/bin/python3
# Copyright 2020 Hewlett Packard Enterprise Development LP

"""A cloud-init 'like' module to update-ca certs. Expects ~ cPython 3.6+."""

import io
import os
import json
import subprocess as subp
import sys

import logging
from cryptography import x509
from cryptography.hazmat.backends import default_backend

# Example minimal data structure of the ca-certs metadata item
#
# {
#     "remove-defaults": false,
#     "trusted": [
#         "-----BEGIN CERTIFICATE-----\nMIIErTCCAxWgAwIBAgIJAIBV7xOFTIbiMA0GCSqGSIb3DQEBCwUAMGExDzANBgNV\nBAoMBlNoYXN0YTERMA8GA1UECwwIUGxhdGZvcm0xOzA5BgNVBAMMMlBsYXRmb3Jt\nIENBICgwQ0U5MDYyQy1BMTNELTRDMDEtOUIyOC0yM0FDRERGRjQ3M0EpMB4XDTIw\nMTAxNDAxNTgwMVoXDTMwMTAxMjAxNTgwMVowZjEPMA0GA1UECgwGU2hhc3RhMREw\nDwYDVQQLDAhQbGF0Zm9ybTFAMD4GA1UEAww3UGxhdGZvcm0gQ0EgLSBMMSAoMENF\nOTA2MkMtQTEzRC00QzAxLTlCMjgtMjNBQ0RERkY0NzNBKTCCAaIwDQYJKoZIhvcN\nAQEBBQADggGPADCCAYoCggGBALv5y/TUWpp2zYR0GOALffxAkGv3Rhx/T8wO36qP\n3sn1h+nsWCHGxQFdZw2zUVPpU7T8+4H8dqXNTq0XKRd2+F7YNVRfVMHLc+hHc2De\nhBWbwGCChmez4b906yZSa8fSKRre0WC1bqLgG3RW92ommWKlv9rvja3pAN0C9P/+\nRD3s3nLPshIUDapfuNuNECij+6FtFqlL9s2HG8SmzGkLANKGGUBXU3qtPRys73/Z\nhMYBMNeryGjq60USY1EuUJjWOZODp6+yDf3l+9OwmRbHP5WWL8UXBjocLSD6Wx0g\nhvf4nPZOGagBzzicWfAKWFSC8wpUmXGv4Ji8kHF9IZfrmAOGLQCGJf2wCTER3IP/\n83XNzjuQ2PS9JNPquNrT7lTIrvAfNvgD1YWW+MgRDHs1gHC6wDwuVh+9YrX9AU9/\nHAh83hporAoD7jtWs1s587yHkXNJYU5WYuYqDPvf1xN5/N5ZdLd4GODo1rHhCUlv\nuWCsPxysYkEJxFHH3MQESshSzwIDAQABo2MwYTAPBgNVHRMBAf8EBTADAQH/MA4G\nA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUwqFi7mGpQMtw1IHWIlPqe8/blqEwHwYD\nVR0jBBgwFoAUN/ynyCHB5GiGz0LY4vPTi8+dPVowDQYJKoZIhvcNAQELBQADggGB\nAIOh7cwVPKaKCkNEjPJvjp70WI1oU3fmvNXC72AEmgfI6rpihKoKpfJa+JQLZ2L/\nm2wipRi7geXisRzJQ3cKCF2RxNRkwlUBQXISTbjUtxFdJFI0Mjq001OP3Twhr2RA\nDPIlDXvvfm1VhrMBT8RJL8mmU65e7+6g3sD6+efWkeG5H5Wilk6eHDbfqwXbLyLM\nJw6JdtRRAKethjVqb+KSRr7Zjzz//xr5M+my4J3P4g8raKjmPkTptLywBLJAKMDr\nLVmSpWmIe/p6PEISCtS0X76LrnH5auNP6cFomAtQ7q6aRN7hrWi90n8xQHTX+v15\nIMdi5x71/niJr8HCm2+2n1wMxS+wM+fv1uHe83CbPfDFxxpFZRMnbhggrwlNT/e5\nEi3obyHf4dKDWnRuWG2VtWcwIAQVHLv8CPWldQPN10RCQaJaB+6easbBgVNlrHRj\nPYUXpzu5UunXwKC3loo8u4zre3GDgquCR6Y9Ma4TxOOsoMdqgMaivuOkVfkicY8P\nDQ==\n-----END CERTIFICATE-----\n",
#         "-----BEGIN CERTIFICATE-----\nMIIEhzCCAu+gAwIBAgIJAKw2Uj8KEsFeMA0GCSqGSIb3DQEBCwUAMGExDzANBgNV\nBAoMBlNoYXN0YTERMA8GA1UECwwIUGxhdGZvcm0xOzA5BgNVBAMMMlBsYXRmb3Jt\nIENBICgwQ0U5MDYyQy1BMTNELTRDMDEtOUIyOC0yM0FDRERGRjQ3M0EpMB4XDTIw\nMTAxNDAxNTgwMVoXDTMwMTAxMzAxNTgwMVowYTEPMA0GA1UECgwGU2hhc3RhMREw\nDwYDVQQLDAhQbGF0Zm9ybTE7MDkGA1UEAwwyUGxhdGZvcm0gQ0EgKDBDRTkwNjJD\nLUExM0QtNEMwMS05QjI4LTIzQUNEREZGNDczQSkwggGiMA0GCSqGSIb3DQEBAQUA\nA4IBjwAwggGKAoIBgQCrYWrQUp3ZRxfqKDaOQUVdpx/x0+i2K+JJfyp+6UL4Zw43\nf57PdjR753TKAw4ZtRk8OP+SuxMOiJfywz+huOlgZQCGzNWHAnknr8ib1/mMMd+R\n5Qbn5FvriExjXAKnMKXvstqVeFCFIsR6u/gIC7yXKUa8/c+UAeHOfxhCT9z0yXNj\nTG/xODez4t7shIorzaQonnIt/xWqkZx20tIrO66u/cwy9bYG9BhaT88p3yQ4G3kt\nk9ooHOr4y9BhnztU6paQPJ7zDcuSFDOSl08mClrX3YMu2cbOrgajikX7O0L9hzYC\n/LYkNiUlrwYHmiPxCIHhFuyYb5L1UuD7+LIPO0AZIC7WCJYctM4TG8xMuH37Jj0C\nHvI0N0bjgYS2k0p0uoV7ni55RHfShAVP0knR8aAVf8AD3MdHNuaHvSW8OCa1U2DZ\nfqHWXveY2jjztYMrb9GHYScJHpWBGtG4WqyQ24yxQFDbwLY8c9N8iPXoNiAgc36E\nQjwtajUhLrxAi4Bl8LMCAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8B\nAf8EBAMCAQYwHQYDVR0OBBYEFDf8p8ghweRohs9C2OLz04vPnT1aMA0GCSqGSIb3\nDQEBCwUAA4IBgQBsBKZtje/UtnESpq4hVpSnUKDkUi1Q8SrY8Bra2oO9Zl6H4uQU\ngjzB5lLpAKIygJS6yTz4zj24zWX85l1Z41dfbWgMbk0WH6chWFXjkyPdwwFPt1s1\nv/yUqxcL3SLqAjIPRQIvTjKRQYZbwYqDDiwslNkayIvoZ58GsVMh6RvD4pgeC5lf\nS0owFBAlZDOGwQRegDVru+ejdoAfp2W+MbN8RG1RNMVaqNK3Y0DE78GMKlW6em8E\n8ook+0P5S8E9V29n5qGlxH6Z485v6hzaQZdehhQ+QCZ903zV6PI1xHw1PkQ9Rv8C\nAwqtg/LaVIJDjebUxZQt2QmIepcMs27aSFgq24pI7+k89cz9C1mXRQa4+8wCsDmm\ntxchn3vr/kHelhuJMDHASnD4Lx9p3dJ8Ka9CBe8F+Dv4gsY5wJDnE6bTfhRdlfcL\nIBIRRB5T2GsiQe4u1pXLwib8VdSWM27LCo8/26Z0tWsfkFVqjp+vxwy8N/CgwanC\nfQvoU4qp9eC4p6s=\n-----END CERTIFICATE-----\n"
#     ]
# }

UPDATE_CA_CMD = ["update-ca-certificates"]
CRAYSYS_META_CMD = ["craysys", "metadata", "get", "ca_certs"]

# SLES CA Path
# https://www.suse.com/support/kb/doc/?id=000019003
CA_CERT_PATH_SLES = "/etc/pki/trust/anchors/"
CA_CERT_FILENAME = "platform-ca-certs.crt" # use different path from upstream cloud-init ca module
CA_CERT_FULLPATH = os.path.join(CA_CERT_PATH_SLES,CA_CERT_FILENAME)

logging.basicConfig(
    format='%(asctime)s %(levelname)s:%(filename)s(%(lineno)d) %(message)s',
    level=logging.DEBUG)


def get_ca_meta():
    """
    Try to retrieve cert-related cloud-init metadata.

    Returns ca_certs data structure on success, None otherwise.
    """

    try:
        p = subp.run(CRAYSYS_META_CMD,
                     stdout=subp.PIPE,
                     stderr=subp.PIPE,
                     check=True)
        return json.loads(p.stdout)
    except subp.CalledProcessError as e:
        logging.error(
            "Exec failed {}, rc = {}".format(CRAYSYS_META_CMD,e.returncode))
        logging.error(
            "stdout: \n{}".format(e.stdout))
        logging.error(
            "stderr: \n{}".format(e.stderr))
    except FileNotFoundError:
        logging.error(
            "Exec failed, file not found {}".format(CRAYSYS_META_CMD))
    except (ValueError, KeyError):
        logging.error(
           "Failed to load metadata, raw input:\n {}".format(p.stdout))

    return None

def add_ca_certs(certs):
    """
    Adds certificates to PKI trust anchor location.
    @param certs: list of single string, pem encoded, certificates, with
    embedded '\n' newlines.

    Returns True on success, False otherwise.
    """

    if os.path.exists(CA_CERT_FULLPATH):
        logging.info("bundle file exists at {}".format(CA_CERT_FULLPATH))

    if not len(certs):
        logging.info(
            "List of certificates is empty, removing (if exists) {}".format(CA_CERT_FULLPATH))

        try:
            if os.path.isfile(CA_CERT_FULLPATH):
                os.unlink(CA_CERT_FULLPATH)
        except OSError as e:
            logging.error("Unable to unlink file, received: {}".format(e.strerror))

        return True

    logging.info("Found {} certificates".format(len(certs)))

    sbuff = io.StringIO()

    for cert in certs:
        try:
            cert = cert.strip()
            # sanity check, attempt to parse cert
            raw = bytes(cert, "utf-8")
            pem = x509.load_pem_x509_certificate(raw, default_backend())

            # guard against 'empty' lines
            # that could cause pem parsing failures
            # on system.
            for l in cert.split('\n'):
                if len(l.strip()):
                    sbuff.write(l + '\n')
        except (ValueError, TypeError): # primarily for x509.load...
            logging.error("Cannot load cert into x509 format:\n{}".format(cert))
            return False

    try:
        if len(sbuff.getvalue()):
            with open(CA_CERT_FULLPATH, 'w') as f:
                f.write(sbuff.getvalue())
    except IOError:
        logging.error("Error writing PEM files")
        return False

    return True

def update_ca_certs():
    """
    Updates system cache of trusted CA certificates.

    Returns True on success, False otherwise.
    """

    try:
        subp.run(UPDATE_CA_CMD,check=True,stdout=subp.PIPE,stderr=subp.PIPE)
    except subp.CalledProcessError as e:
        logging.error(
            "Unable to exec {}, rc = {}".format(UPDATE_CA_CMD,e.returncode))
        logging.error(
            "stdout: \n{}".format(e.stdout))
        logging.error(
            "stderr: \n{}".format(e.stderr))
        return False
    except FileNotFoundError:
        logging.error(
            "Exec failed, file not found {}".format(UPDATE_CA_CMD))
        return False

    return True

def main():

    logging.info("start")

    # Try to load meta, if no meta found, take no action

    # get cert meta
    cert_meta = get_ca_meta()
    if cert_meta is None:
        logging.error("Unable to load ca-certs metadata")
        sys.exit(1)

    logging.info("loaded ca-certs metadata")

    if 'trusted' not in cert_meta.keys():
        logging.error("'trusted' ca certificates key not in metadata")
        sys.exit(2)

    # Replace certs provisioned by this tool, an empty
    # array will remove CAs installed by this tool, if
    # they exist.

    if not add_ca_certs(cert_meta['trusted']):
        logging.error("unable to add/remove ca certificates")
        sys.exit(3)

    logging.info("Updated certificate bundle at {}".format(CA_CERT_FULLPATH))

    if not update_ca_certs():
        logging.error("unable to update ca certificate cache")
        sys.exit(4)

    logging.info("Updated certificate cache on system")

    logging.info("stop")

if __name__ == "__main__":
    main()

# vi: ts=4 expandtab
