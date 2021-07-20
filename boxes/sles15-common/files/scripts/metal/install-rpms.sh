#!/bin/bash
# Globally disable warning about globbing and word splitting
# shellcheck disable=SC2086

set -e

function paginate() {
    local url="$1"
    local token
    { token="$(curl -sSk "$url" | tee /dev/fd/3 | jq -r '.continuationToken // null')"; } 3>&1
    until [[ "$token" == "null" ]]; do
        {
            token="$(curl -sSk "$url&continuationToken=${token}" | tee /dev/fd/3 | jq -r '.continuationToken // null')";
        } 3>&1
    done
}

# Verify nexus is available.  It's expected to *not* be available during initial install of the NCNs.
if ! curl -sSf https://packages.local/service/rest/v1/components?repository=csm-sle-15sp2 >& /dev/null; then
    echo "unable to contact nexus, bailing"
    exit 0
fi

# Retreive the packages from nexus
goss_servers_url=$(paginate "https://packages.local/service/rest/v1/components?repository=csm-sle-15sp2" \
    | jq -r  '.items[] | .assets[] | .downloadUrl' | grep goss-servers | sort -V | tail -1)
csm_testing_url=$(paginate "https://packages.local/service/rest/v1/components?repository=csm-sle-15sp2" \
    | jq -r  '.items[] | .assets[] | .downloadUrl' | grep csm-testing | sort -V | tail -1)
zypper install -y $goss_servers_url $csm_testing_url && systemctl enable goss-servers && systemctl restart goss-servers
