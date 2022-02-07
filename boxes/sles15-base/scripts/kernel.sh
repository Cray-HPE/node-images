#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
SLES15_KERNEL_VERSION="5.3.18-24.99.1"

KERNEL_PACKAGES=(kernel-default-debuginfo-"$SLES15_KERNEL_VERSION"
kernel-default-devel-"$SLES15_KERNEL_VERSION"
kernel-default-debugsource-"$SLES15_KERNEL_VERSION"
kernel-default-"$SLES15_KERNEL_VERSION")

zypper addrepo "https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Product-SLES/15-SP2-LTSS/x86_64/update/?auth=basic" sles15sp2-Product-SLES-LTSS-update
zypper addrepo "https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Product-SLES/15-SP2-LTSS/x86_64/update_debug/?auth=basic" sles15sp2-Product-SLES-LTSS-update_debug

zypper --non-interactive remove $(rpm -qa | grep kernel-default)
eval zypper --plus-content debug --non-interactive install --no-recommends --oldpackage "${KERNEL_PACKAGES[*]}"
sed -i 's/^multiversion.kernels =.*/multiversion.kernels = '"${SLES15_KERNEL_VERSION}"'/g' /etc/zypp/zypp.conf
zypper --non-interactive purge-kernels --details
zypper addlock kernel-default

zypper cleanup --repo sles15sp2-Product-SLES-LTSS-update --repo sles15sp2-Product-SLES-LTSS-update_debug
zypper removerepo sles15sp2-Product-SLES-LTSS-update sles15sp2-Product-SLES-LTSS-update_debug

zypper ll

rpm -qa | grep kernel-default
