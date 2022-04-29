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

# This script does not use bind mounts and thus executes correctly in a container
set -euf -o pipefail

# Run cleanup on exit
trap cleanup EXIT

# Optional debug flag
if [[ "${DEBUG:=false}" == "true" ]]; then
    set -x
fi

# cleanup() unmounts the temporary wipe hack and other cleanup tasks
function cleanup() {
  if [[ "${APPEND_NO_WIPE1}" == "true" ]]; then
    umount /proc/cmdline
  fi
}

# mount_bootraid() mounts the bootraid device
function mount_bootraid() {
  if ! grep -q "${BOOTRAID}" <<< "$(cat /proc/mounts)"; then
    if ! mount -L BOOTRAID -T /etc/fstab.metal; then
      echo "Failed to mount BOOTRAID"
    fi
  fi
}

# normalize_fstab() makes sure fstab is in a nice format for machines to manipulate
function normalize_fstab() {
  local fstab="${1}"
  #   - initial TABs and SPACEs are removed
  #   - empty lines and comments are removed
  #   - fields are separated by a single TAB
  sed -e 's/[ \t][ \t]*/\t/g;s/^\t//;/^$/d;/^#/d' \
      "${fstab}"
}		

# get_mp() gets a mountpoint given a device
function get_mp() {
  local device="${1}"
  # if the first field matches, return the mount point
  awk -v l="$device" '{if($1 == l) print $2}' <<< "$(normalize_fstab /etc/fstab.metal)"
}

# get_initrd_version() gets the initrd version from a given initrd file by checking its build-parameters
function get_initrd_vers() {
  local initrd_path="${1}"
  # The current 'initrd.img.xz' version is likely to match the NEW_KERNEL_VERS,
  # but it could potentially be different, so this runs through
  # a big check by matching the build-parameters in the 'initrd.img.xz'
  # and using that as the filename when it is backed up
  /usr/lib/dracut/skipcpio "${initrd_path}" \
    | xzcat \
    | cpio \
    --extract \
    --quiet \
    --to-stdout -- lib/dracut/build-parameter.txt \
    | sed -n  's/.*\(--kver\)/\1/p' \
    | awk -F"'" '{print $2}'
}

# check_wipe_status() checks the status of the wipe and fails if set to 0
function check_wipe_status() {
  # get the current kernel parameters
  local cmdline=""
  cmdline=$(cat /proc/cmdline)

  for param in $cmdline; do
      # check the only wipe status
      if [[ "${param}" =~ ^metal\.no-wipe.* ]]; then
        if [[ "${param}" == "metal.no-wipe=0" ]]; then
          >&2 echo "${param} found.  Setting 'metal.no-wipe=1 to override"
          # bind mount a temporary file to /proc/cmdline to override the wipe setting
          APPEND_NO_WIPE1="true"
          wipe_hack
          break
        fi
      fi
  done
}

# wipe_hack() toggles metal.no-wipe=0 to 1 by mounting a temp file over /proc/cmdline with the desired value
function wipe_hack() {
  local psuedo_cmdline="/tmp/cmdline"
  if [[ "${APPEND_NO_WIPE1}" == "true" ]]; then
    # copy the current cmdline to a temp file
    cp -p /proc/cmdline "${psuedo_cmdline}"
    # replace metal.no-wipe=0 with metal.no-wipe=1
    sed -i 's/metal.no-wipe=0/metal.no-wipe=1/g' "${psuedo_cmdline}"
    # mount the modified cmdline over the proc file
    mount --bind "${psuedo_cmdline}" /proc/cmdline
  fi
}

# replace_kernel_in_bootraid() copied new kernel to the bootraid and backs up the existing one
function replace_kernel_in_bootraid() {
  if [[ ! -f "${CUR_KERNEL_PATH}" ]]; then
    # This script will populate the boot partition 
    # but warn the user it may have been in an unstable state prior to this
    echo "Warning: Non-fatal: missing artifact in boot partition"
  else
    # Move the existing kernel out of the way
    # BOOTRAID/boot/kernel ---> BOOTRAID/boot/<kernel-version>
    mv "${CUR_KERNEL_PATH}" "${CUR_KERNEL_NEW_NAME}"
  fi

  # Copy the new kernel to the boot partition as 'kernel'
  # /boot/<kernel-version> ---> BOOTRAID/boot/kernel
  cp "${NEW_KERNEL_PATH}" "${CUR_KERNEL_PATH}"
}

# replace_initrd_in_bootraid() copies the new initrd to the bootraid and backs up the existing one
function replace_initrd_in_bootraid() {
  if [[ ! -f "${CUR_INITRD_PATH}" ]]; then
    # This script will populate the boot partition 
    # but warn the user it may have been in an unstable state prior to this
    echo "Warning: Non-fatal: missing artifact in boot partition"
  else
    local cur_initrd_vers=""
    cur_initrd_vers="initrd-$(get_initrd_vers "${CUR_INITRD_PATH}")"
    local cur_initrd_dir=""
    cur_initrd_dir="$(dirname "${CUR_INITRD_PATH}")"

    # Move the existing kernel out of the way
    # BOOTRAID/boot/initrd.img.xz ---> BOOTRAID/boot/initrd-<old-kernel-version>
    mv "${CUR_INITRD_PATH}" "${cur_initrd_dir}/${cur_initrd_vers}"
  fi

  # Copy the newly-generated initrd to the default file name so it's picked up on the next boot
  # BOOTRAID/boot/initrd-<kernel-version> ---> BOOTRAID/boot/initrd.img.xz
  cp "${NEW_INITRD_PATH}" "${CUR_INITRD_PATH}"
}

# update_bootraid_artifacts() backs up the existing kernel and initrd, and then replaces them with the new ones
function update_bootraid_artifacts() {
  replace_kernel_in_bootraid
  replace_initrd_in_bootraid
}

# create_new_initrd() creates a new initrd with the new kernel version
function create_new_initrd() {
  local kver="${1}"
  local initrd_path="${2}"

  # args for dracut
  omit+="btrfs "
  omit+="cifs "
  omit+="dmraid "
  omit+="dmsquash-live-ntfs "
  omit+="fcoe "
  omit+="fcoe-uefi "
  omit+="iscsi "
  omit+="modsign "
  omit+="multipath "
  omit+="nbd "
  omit+="ntfs-3g "
  omit+="nfs "
  omit+="rdma "
  echo ">> omit=\"$omit\"" >/dev/null

  omit_drivers+="ecb "
  omit_drivers+="hmac "
  omit_drivers+="md5 "
  echo ">> omit_drivers=\"$omit_drivers\"" >/dev/null

  dracut_add+="dmsquash-live "
  dracut_add+="livenet "
  dracut_add+="mdraid"
  echo ">> dracut_add=\"$dracut_add\"" >/dev/null

  dracut_install+="less "
  dracut_install+="rmdir "
  dracut_install+="sgdisk "
  dracut_install+="systemd-analyze "
  dracut_install+="vgremove "
  dracut_install+="wipefs "
  echo ">> dracut_install=\"$dracut_install\"" >/dev/null

  dracut_drivers+="raid1 "
  echo ">> dracut_drivers=\"$dracut_drivers\"" >/dev/null

  # create the initrd
  dracut \
    -L "${DRACUT_DEBUG:=3}" \
    --xz \
    --force \
    --omit "${omit}" \
    --omit-drivers "${omit_drivers}" \
    --add "${dracut_add}" \
    --add-drivers "${dracut_drivers}" \
    --install "${dracut_install}" \
    --nohardlink \
    --no-hostonly-cmdline \
    --persistent-policy by-label \
    --ro-mnt \
    --no-hostonly \
    --kver "${kver}" \
    "${initrd_path}"
}

# usage() Generates a usage line
# Any line startng with with a #/ will show up in the usage line
usage() {
  grep '^#/' "$0" | cut -c4-
}

#/ Usage: command -k <kernel-path>
#/
#/    Switches the kernel to the one specified by <kernel-path>
#/
#/    Procedure to live patch the kernel:
#/        0. Install the new kernel rpm
#/        1. Set metal.no-wipe=1
#/        2. Drain the node
#/        3. Run this script
#/        4. kexec -e
#/        5. Validate NCN health (healthchecks, GOSS tests, ceph health, etc)
#/        6. Upload the new kernel and initrd to S3
#/

if [[ $# -eq 0 ]]; then
  echo -e "No arguments provided.\n"
  usage
  exit 1
fi

# set_globals() sets global variables
set_globals() {
  local kver="${1}"

  # /boot != BOOTRAID, where the artifacts are stored
  #shellcheck disable=SC2155
  readonly BOOTRAID="$(get_mp LABEL=BOOTRAID)"

  # Paths to the existing kernel and initrd
  # CSM hardcodes these as 'kernel' and 'initrd.img.xz' in the boot command line
  readonly CUR_KERNEL_PATH="${BOOTRAID}"/boot/kernel
  readonly CUR_INITRD_PATH="${BOOTRAID}"/boot/initrd.img.xz

  # Find the existing 'kernel' version by checking it with 'file' and parsing out the Version
  # this will be used to backup the existing 'kernel' and rename it appropriately
  CUR_KERNEL_FILE_VERS=""
  CUR_KERNEL_FILE_VERS=$(file -b "${CUR_KERNEL_PATH}" | tr ',' '\n' | awk '!/Setup/ && /Version/ {print $2}')
  CUR_KERNEL_NEW_NAME="$(dirname "${CUR_KERNEL_PATH}")"/"${CUR_KERNEL_FILE_VERS}"

  # get the new kernel version from path
  readonly NEW_KERNEL_PATH="${kver}"
  # get just the filename
  readonly NEW_KERNEL_FILE=${NEW_KERNEL_PATH##*/}
  # remove vmlinuz- to get just the version
  readonly NEW_KERNEL_VERS=${NEW_KERNEL_FILE/vmlinuz-/}

  # Set the path for the new initrd
  # This is saved to the BOOTRAID, not /boot in the squashfs root
  NEW_INITRD_PATH="$(dirname "$CUR_INITRD_PATH")"/initrd-"${NEW_KERNEL_VERS}"

  # By default, don't try to modify the wipe parameter
  APPEND_NO_WIPE1="false"
}

# Parse arguments
while getopts "hk:" opt; do
  case ${opt} in
    h) usage
      ;;
    k) # Set global variables
      set_globals "${OPTARG}"

      # mount the local boot partition so the new artifacts can be copied there
      echo "Mounting bootraid..."
      mount_bootraid

      echo "Generating initrd for ${NEW_KERNEL_VERS}..."
      # Create the new initrd that will be used to boot the new kernel which has support for overlay/squashfs
      create_new_initrd "${NEW_KERNEL_VERS}" "${NEW_INITRD_PATH}"

      echo "Copying new kernel and initrd to bootraid..."
      # Backup the existing artifacts and replace them with the newly created ones
      update_bootraid_artifacts
      
      # check the wipe status before continuing, modifying it if necessary
      echo "Checking wipe status..."
      check_wipe_status 

      # Load the new kernel
      # The user can manually execute and switch to the new kernel when they are ready using kexec
      # It's critical to reuse the cmdline here so that the node boots back with its existing settings
      # However, it needs the newly-generated initrd, which has support built in for overlay/squashfs
      echo "Staging new kernel..."
      kexec --load \
        --reuse-cmdline \
        --initrd="${NEW_INITRD_PATH}" \
        "${NEW_KERNEL_PATH}"

      echo "Run 'kexec -e' to use the new kernel."
      
      shift
      ;;
    \?)
      echo "Invalid Option: -$OPTARG" 1>&2
      exit 1
      ;;
    :)
      echo "Invalid Option: -$OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))
