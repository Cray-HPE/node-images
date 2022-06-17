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
  echo "Error: the variable SLES15_REGISTRATION_CODE must be set"
  exit 1
fi

# GOOGLE is always a "teeny bit" behind in adopting the latest SLES release,
# therefore VSHASTA images need to "lag" behind for a moment. Eventually Google
# does catch-up, so the values above and below for SLES15_SP_VERSION _do_ and _don't_
# match ... from time-to-time.

export SLES15_SP_VERSION="15.3"
envsubst < $root_dir/boxes/sles15-base/http/autoinst.template.xml > $root_dir/boxes/sles15-base/http/autoinst-google.xml

[ -n "$SLES15_BETA_REGISTRATION_CODE" ] && export SLES15_REGISTRATION_CODE="$SLES15_BETA_REGISTRATION_CODE"
export SLES15_SP_VERSION="15.4"
envsubst < $root_dir/boxes/sles15-base/http/autoinst.template.xml > $root_dir/boxes/sles15-base/http/autoinst.xml
