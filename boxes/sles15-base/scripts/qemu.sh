#!/bin/bash

set -ex

# install required packages
packages=( jq )
zypper --non-interactive install --no-recommends --force-resolution "${packages[@]}"