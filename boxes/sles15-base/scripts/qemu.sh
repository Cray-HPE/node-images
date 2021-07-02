#!/usr/bin/env bash

set -e

# install required packages
packages=( jq )
zypper --non-interactive install --no-recommends --force-resolution "${packages[@]}"
