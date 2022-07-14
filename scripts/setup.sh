#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
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


[ -n "$SLES15_BETA_REGISTRATION_CODE" ] && export SLES15_REGISTRATION_CODE="$SLES15_BETA_REGISTRATION_CODE"
export SLES15_SP_VERSION="15.3"
envsubst < $root_dir/boxes/sles15-base/http/autoinst.template.xml > $root_dir/boxes/sles15-base/http/autoinst.xml
