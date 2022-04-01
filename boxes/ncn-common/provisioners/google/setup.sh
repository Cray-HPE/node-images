#!/bin/bash

set -e

# TODO: This might not be needed
echo "activate public cloud module"
product=$(SUSEConnect --list-extensions | grep -o "sle-module-public-cloud.*")
[[ -n "$product" ]] && SUSEConnect -p "$product"
