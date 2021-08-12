#!/bin/bash
#
# Copyright 2020 Hewlett Packard Enterprise Development LP
#
# System Dump Utility podman wrapper script and systemd configuration
#
# RPM Packages Installed By Inventory
#
#   cray-sdu-rda:
#       Purpose: Provides the "sdu" command and an associated man page.
#                The sdu command is a wrapper for running the system dump
#                utility inside a podman container.
#
#                Additionally, a cray-sdu-rda systemd service will be
#                added, but not enabled.
#
#########################################################################
set -e
