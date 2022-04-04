#!/usr/bin/env bash

set -e

#======================================
# Force root user to change password
# at first login.
#--------------------------------------
chage -d 0 root