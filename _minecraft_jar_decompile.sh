#!/bin/bash

# References:
# https://github.com/hpfxd/PandaSpigot
# https://github.com/PaperMC/Paper-archive

# Do not run this script directly

PS1="$"
WORKING_DIR="$1"

windows="$([[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]] && echo "true" || echo "false")"

minecraft_version="$(cat "${WORKING_DIR}/Panda/base/Paper/BuildData/info.json" | grep minecraftVersion | cut -d '"' -f 4)"
decompilation_mcdev_dir="${WORKING_DIR}/mc-dev"
decompilation_spigot_dir="${decompilation_mcdev_dir}/spigot"
decompilation_classes_dir="${decompilation_mcdev_dir}/classes"
minecraft_version_json="${decompilation_mcdev_dir}/${minecraft_version}.json"
wget_dir="${WORKING_DIR}/tmp"
minecraft_version_manifest_json="${decompilation_mcdev_dir}/version_manifest.json"
decompilation_server_jar_mapped="${decompilation_mcdev_dir}/${minecraft_version}-mapped.jar"
decompilation_nms="${decompilation_spigot_dir}/net/minecraft/server"

if [[ ! -f "${wget_dir}/version_manifest.json" ]]; then
  echo "Downloading version manifest"
  if ! wget --progress=dot:mega -O "${wget_dir}/version_manifest.json" "https://launchermeta.mojang.com/mc/game/version_manifest.json"; then
    echo "Cannot download version manifest!!!"
    exit 1
  fi
fi

cp "${wget_dir}/version_manifest.json" "${minecraft_version_manifest_json}"

if [[ ! -f "${minecraft_version_json}" ]]; then
  _verescaped=$(echo "${minecraft_version}" | sed 's/\-pre/ Pre-Release /g' | sed 's/\./\\./g')
  _urlescaped=$(echo "${_verescaped}" | sed 's/ /_/g')
  _verentry=$(cat "${minecraft_version_manifest_json}" | grep -oE "\{\"id\": \"${_verescaped}\".*${_urlescaped}\.json")
  _jsonurl=$(echo "${_verentry}" | grep -oE https:\/\/.*\.json)
  echo "Downloading ${minecraft_version} version manifest"
  if ! wget --progress=dot:mega -O "${minecraft_version_json}" "${_jsonurl}"; then
    echo "Cannot download ${minecraft_version} version manifest!!!"
    exit 1
  fi
fi

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
