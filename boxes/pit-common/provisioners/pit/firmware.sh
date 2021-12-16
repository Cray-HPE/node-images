#!/usr/bin/env bash

set -e

#======================================
# Firmware comes from HFP, but we can still keep these directories for convenience and backwards compatibility
#--------------------------------------
mkdir -pv /var/www/fw/river/hpe
mkdir -pv /var/www/fw/network
mkdir -pv /var/www/fw/pcie

#======================================
# Download and extract River BIOS, BMC, and CMC.
#   The fw images will be available at
#   http://$(ip a show vlan004 | grep inet | awk '{print $2}')/fw/river/{128409,628402,MZ32,MZ62,MZ92}*
#--------------------------------------
declare -r BIOS_RVR_BASE_URL=https://stash.us.cray.com/projects/BIOSRVR/repos/bios-rvr/raw
declare dataDir=${DATA_DIR:-/var/www/fw/river} \
        branch="refs%2Fheads%2Fmaster" \
        branch=refs%2Fheads%2Frelease%2Fshasta-1.4 \
        shSvrScriptsUrl=${BIOS_RVR_BASE_URL}/sh-svr-scripts \
        biosUrls="${BIOS_RVR_BASE_URL}/sh-svr-1264up-bios/BIOS/MZ32-AR0-YF_C17_F01.zip ${BIOS_RVR_BASE_URL}/sh-svr-3264-bios/BIOS/MZ62-HD0-YF_C20_F01b.zip ${BIOS_RVR_BASE_URL}/sh-svr-5264-gpu-bios/BIOS/MZ92-FS0-YF_C20_F01.zip" \
        bmcUrl=${BIOS_RVR_BASE_URL}/sh-svr-3264-bios/BMC/128409.zip \
        cmcUrl=${BIOS_RVR_BASE_URL}/sh-svr-3264-bios/CMC/628402.zip \
        line= fileName= curUrl=
mkdir -p ${dataDir}/${shSvrScriptsUrl##*/}
printf -- "Downloading sh-svr-scripts ... "
while read line; do #{
  set ${line} >/dev/null 2>&1
  [ ${#} -eq 4 ] || continue
  fileName=${4}
  curl -sL ${shSvrScriptsUrl}/${fileName}?at=${branch} -o ${dataDir}/${shSvrScriptsUrl##*/}/${fileName} &
done< <(curl -sk ${shSvrScriptsUrl}?at=${branch}) #}
wait
printf -- "DONE\n"
printf -- "Downloading River BIOS, BMC, and CMC ... "
for curUrl in ${biosUrls} ${bmcUrl} ${cmcUrl}; do #{
  curl -sL ${curUrl}?at=${branch} -o ${dataDir}/${curUrl##*/} &
done #}
wait
printf -- "DONE\n"
printf -- "Extracting BIOS, BMC, and CMC into ${dataDir} ... "
for zipArchive in ${biosUrls} ${bmcUrl} ${cmcUrl}; do #{
  python3 -m zipfile -e ${dataDir}/${zipArchive##*/} ${dataDir}/ &
done #}
wait
printf -- "DONE\n"
printf -- "Removing unused files & directories.\n"
find ${dataDir}/1* -maxdepth 1 ! -name fw | tail -n+2 | xargs rm -rf
find ${dataDir}/6* -maxdepth 1 ! -name fw | tail -n+2 | xargs rm -rf
find ${dataDir}/MZ3* -maxdepth 1 ! -name RBU | tail -n+2 | xargs rm -rf
find ${dataDir}/MZ6* -maxdepth 1 ! -name RBU | tail -n+2 | xargs rm -rf
find ${dataDir}/MZ9* -maxdepth 1 ! -name RBU | tail -n+2 | xargs rm -rf
