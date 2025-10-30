#!/bin/bash

# References:
# https://github.com/hpfxd/PandaSpigot
# https://github.com/PaperMC/Paper-archive

# Do not run this script directly

set -u

PS1="$"
WORKING_DIR="$1"

minecraft_version="$(cat "${WORKING_DIR}/Panda/base/Paper/BuildData/info.json" | grep minecraftVersion | cut -d '"' -f 4)"
decompilation_mcdev_dir="${WORKING_DIR}/mc-dev"
decompilation_spigot_dir="${decompilation_mcdev_dir}/spigot"
decompilation_classes_dir="${decompilation_mcdev_dir}/classes"
wget_dir="${WORKING_DIR}/tmp"
decompilation_server_jar_mapped="${decompilation_mcdev_dir}/${minecraft_version}-mapped.jar"
decompilation_nms="${decompilation_spigot_dir}/net/minecraft/server"

mkdir -p "${decompilation_spigot_dir}" || true

if [[ ! -d "${decompilation_classes_dir}" ]]; then
  echo "Extracting NMS classes"
  mkdir -p "${decompilation_classes_dir}" || true
  cd "${decompilation_classes_dir}"
  if ! jar xf "${decompilation_server_jar_mapped}" net/minecraft/server yggdrasil_session_pubkey.der assets; then
    cd "${WORKING_DIR}"
    echo "Failed to extract NMS classes!!!"
    exit 1
  fi
fi

if [[ -d "${decompilation_nms}" ]]; then
  cp -r "${decompilation_nms}" "${decompilation_spigot_dir}/"
fi

cd "${WORKING_DIR}"

if [[ ! -d "${decompilation_nms}" ]]; then
  echo "Decompiling classes"
  java -version
  set -x
  if ! java -jar "${WORKING_DIR}/Panda/base/Paper/BuildData/bin/fernflower.jar" -den=1 -dgs=1 -hdc=0 -rbr=0 -asc=1 -udv=0 "${decompilation_classes_dir}" "${decompilation_spigot_dir}"; then
    set +x
    rm -rf "${decompilation_spigot_dir}/net"
    echo "Failed to decompile classes!!!"
    exit 1
  fi
  set +x
fi
