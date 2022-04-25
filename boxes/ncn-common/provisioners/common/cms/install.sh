#!/bin/bash
# Copyright 2020 Hewlett Packard Enterprise Development LP

set -e

echo "Enabling HPE CSM CMS services"
systemctl enable cfs-state-reporter.service
