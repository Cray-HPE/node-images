#!/bin/bash
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
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

# This script does not use bind mounts and thus executes correctly in a container.
set -e
set -x


# Source common dracut parameters.
. "$(dirname $0)/dracut-lib.sh"

echo "Generating initrd..."

dracut \
--force \
--omit "$(printf '%s' "${OMIT[*]}")" \
--omit-drivers "$(printf '%s' "${OMIT_DRIVERS[*]}")" \
--add "$(printf '%s' "${ADD[*]}")" \
--force-add "$(printf '%s' "${FORCE_ADD[*]}")" \
--install "$(printf '%s' "${INSTALL[*]}")" \
--kver "${KVER}" \
--no-hostonly \
--no-hostonly-cmdline \
--printsize \
--xz \
"/boot/initrd-${KVER}"

"$(dirname $0)/create-kdump-artifacts.sh"

exit 0
