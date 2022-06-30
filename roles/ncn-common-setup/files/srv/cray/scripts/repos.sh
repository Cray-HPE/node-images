#!/bin/bash

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

set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd )"
echo "$CURRENT_DIR"

function list-custom-repos-file() {
  cat <<EOF
${CURRENT_DIR}/${CUSTOM_REPOS_FILE}
EOF
}

function remove-comments-and-empty-lines() {
  sed -e 's/#.*$//' -e '/^[[:space:]]*$/d'
}

function zypper-add-repos() {
  remove-comments-and-empty-lines \
  | awk '{ NF-=1; print }' \
  | while read url name flags; do
    local alias="buildonly-${name}"
    echo "Adding repo ${alias} at ${url}"
    zypper -n addrepo $flags "${url}" "${alias}"
    zypper -n --gpg-auto-import-keys refresh "${alias}"
  done
}

if [ -z "$CUSTOM_REPOS_FILE" ]; then
  echo "Not using a custom repo."
  source /srv/cray/csm-rpms/scripts/rpm-functions.sh
else
  echo "Using custom repos file: '${CUSTOM_REPOS_FILE}'."
  list-custom-repos-file | xargs -r cat | zypper-add-repos
fi
