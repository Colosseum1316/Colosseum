#!/bin/bash

# References:
# https://github.com/hpfxd/PandaSpigot
# https://github.com/PaperMC/Paper-archive

# Do not run this script directly

set -u

PS1="$"
WORKING_DIR="$1"

minecraft_version="$(cat "${WORKING_DIR}/Panda/base/Paper/BuildData/info.json" | grep minecraftVersion | cut -d '"' -f 4)"
minecraft_server_jar_download_url="https://launcher.mojang.com/v1/objects/5fafba3f58c40dc51b5c3ca72a98f62dfdae1db7/server.jar"
minecraft_server_jar_hash=$(cat "${WORKING_DIR}/Panda/base/Paper/BuildData/info.json" | grep minecraftHash | cut -d '"' -f 4)
decompilation_accesstransforms="${WORKING_DIR}/Panda/base/Paper/BuildData/mappings/"$(cat "${WORKING_DIR}/Panda/base/Paper/BuildData/info.json" | grep accessTransforms | cut -d '"' -f 4)
decompilation_classmappings="${WORKING_DIR}/Panda/base/Paper/BuildData/mappings/"$(cat "${WORKING_DIR}/Panda/base/Paper/BuildData/info.json" | grep classMappings | cut -d '"' -f 4)
decompilation_membermappings="${WORKING_DIR}/Panda/base/Paper/BuildData/mappings/"$(cat "${WORKING_DIR}/Panda/base/Paper/BuildData/info.json" | grep memberMappings | cut -d '"' -f 4)
decompilation_packagemappings="${WORKING_DIR}/Panda/base/Paper/BuildData/mappings/"$(cat "${WORKING_DIR}/Panda/base/Paper/BuildData/info.json" | grep packageMappings | cut -d '"' -f 4)
decompilation_mcdev_dir="${WORKING_DIR}/mc-dev"
wget_dir="${WORKING_DIR}/tmp"
decompilation_server_jar="${decompilation_mcdev_dir}/${minecraft_version}.jar"
decompilation_server_jar_cl="${decompilation_mcdev_dir}/${minecraft_version}-cl.jar"
decompilation_server_jar_m="${decompilation_mcdev_dir}/${minecraft_version}-m.jar"
decompilation_server_jar_mapped="${decompilation_mcdev_dir}/${minecraft_version}-mapped.jar"
mkdir -p "${wget_dir}" || true
mkdir -p "${decompilation_mcdev_dir}" || true

if [[ ! -f "${wget_dir}/server.jar" ]]; then
  echo "Downloading vanilla server jar"
  if ! wget --progress=dot:giga -O "${wget_dir}/server.jar" "${minecraft_server_jar_download_url}"; then
    echo "Failed to download the server jar!!!"
    exit 1
  fi
fi

set -e
cp "${wget_dir}/server.jar" "${decompilation_server_jar}"
set +e

# OS X & FreeBSD don't have md5sum, just md5 -r
command -v md5sum >/dev/null 2>&1 || {
  command -v md5 >/dev/null 2>&1 && {
    shopt -s expand_aliases
    alias md5sum="md5 -r"
  } || {
    echo >&2 "No md5sum or md5 command found!!!"
    exit 1
  }
}

_checksum="$(md5sum "${decompilation_server_jar}" | cut -d ' ' -f 1)"
if [[ "${_checksum}" != "${minecraft_server_jar_hash}" ]]; then
  echo "The MD5 checksum of the downloaded server jar does not match!!!"
  exit 1
fi

set -e

./_specialsource.sh "$WORKING_DIR"
java -version

set +e

if [[ ! -f "${decompilation_server_jar_cl}" ]]; then
  echo "Applying class mappings"
  set -x
  if ! java -jar "${wget_dir}/SpecialSource-2.jar" map -i "${decompilation_server_jar}" -m "${decompilation_classmappings}" -o "${decompilation_server_jar_cl}" 1>/dev/null; then
    set +x
    echo "Failed to apply class mappings!!!"
    exit 1
  fi
  set +x
fi

if [[ ! -f "${decompilation_server_jar_m}" ]]; then
  echo "Applying member mappings"
  set -x
  if ! java -jar "${wget_dir}/SpecialSource-2.jar" map -i "${decompilation_server_jar_cl}" -m "${decompilation_membermappings}" -o "${decompilation_server_jar_m}" 1>/dev/null; then
    set +x
    echo "Failed to apply member mappings!!!"
    exit 1
  fi
  set +x
fi

if [[ ! -f "${decompilation_server_jar_mapped}" ]]; then
  echo "Creating remapped jar"
  set -x
  if ! java -jar "${wget_dir}/SpecialSource.jar" --kill-lvt -i "${decompilation_server_jar_m}" --access-transformer "${decompilation_accesstransforms}" -m "${decompilation_packagemappings}" -o "${decompilation_server_jar_mapped}" 1>/dev/null; then
    set +x
    echo "Failed to create remapped jar!!!"
    exit 1
  fi
  set +x
fi
