#!/bin/bash

set -ex

# install required packages
packages=( jq gptfdisk parted )
zypper --non-interactive install --no-recommends --force-resolution "${packages[@]}"