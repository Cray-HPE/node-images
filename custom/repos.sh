#!/bin/bash

set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd )"
echo "$CURRENT_DIR"

function list-custom-repos-file() {
  cat <<EOF
${CURRENT_DIR}/${CUSTOM_REPOS_FILE}
EOF
}

function remove-comments-and-empty-lines() {
  sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "$@"
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
  setup-package-repos
else
  echo "Using custom repos file: '${CUSTOM_REPOS_FILE}'."
  list-custom-repos-file | xargs -r cat | zypper-add-repos
fi
