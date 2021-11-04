#!/bin/bash

set -e

root_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" >/dev/null 2>&1 && pwd )"
cd $root_dir

if ! command -v envsubst &>/dev/null; then
  echo "Error: the envsubst command is necessary to run this build"
  exit 1
fi
if [ -z "$SLES15_INITIAL_ROOT_PASSWORD" ]; then
  echo "Error: the variable SLES15_INITIAL_ROOT_PASSWORD must be set"
  exit 1
fi
if [ -z "$SLES15_REGISTRATION_CODE" ]; then
  echo "Error: the variable SLES15_SLES_REGISTRATION_CODE must be set"
  exit 1
fi

envsubst < $root_dir/boxes/sles15-base/http/autoinst.template.xml > $root_dir/boxes/sles15-base/http/autoinst.xml

if [ -n "$CSM_RPMS_SHA" ]; then
  if [ -d "csm-rpms" ]; then
    echo "Setting csm-rpms to expected hash: $CSM_RPMS_SHA"
    cd csm-rpms
    git checkout "$CSM_RPMS_SHA" --quiet
  fi
fi
