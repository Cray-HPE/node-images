#!/usr/bin/env bash

set -e

# install required packages for virtualbox
packages=( jq )
zypper --non-interactive install --no-recommends --force-resolution "${packages[@]}"
