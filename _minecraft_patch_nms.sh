#!/bin/bash

# References:
# https://github.com/hpfxd/PandaSpigot
# https://github.com/PaperMC/Paper-archive

# Do not run this script directly

PS1="$"
WORKING_DIR="$1"

minecraft_version="$(cat "${WORKING_DIR}/Panda/base/Paper/BuildData/info.json" | grep minecraftVersion | cut -d '"' -f 4)"
minecraft_version="$(cat "${WORKING_DIR}/Panda/base/Paper/BuildData/info.json" | grep minecraftVersion | cut -d '"' -f 4)"
decompilation_mcdev_dir="${WORKING_DIR}/mc-dev"
decompilation_spigot_dir="${decompilation_mcdev_dir}/spigot"
decompilation_nms="${decompilation_spigot_dir}/net/minecraft/server"
_craftbukkit="src/main/java/net/minecraft/server"
_resources="src/main/resources"

alias git="git -c commit.gpgsign=false"

if sed --version >/dev/null 2>&1; then
  function strip_cr {
    sed -i -- "s/\r//" "$@"
  }
else
  function strip_cr {
    sed -i "" "s/$(printf '\r')//" "$@"
  }
fi

patch=$(which patch 2>/dev/null)
if [[ "x$patch" == "x" ]]; then
  patch="${WORKING_DIR}/Panda/base/hctap.exe"
fi

echo "Applying CraftBukkit patches to NMS"
cd "${WORKING_DIR}/Panda/base/Paper/CraftBukkit"
git checkout -B patched HEAD >/dev/null 2>&1
rm -rf "${_craftbukkit}"
mkdir -p "${_craftbukkit}"
while IFS= read -r -d '' file
do
  file="$(echo "$file" | cut -d "/" -f2- | cut -d. -f1).java"
  cp "${decompilation_nms}/${file}" "${_craftbukkit}/${file}"
done < <(find nms-patches -type f -print0)
git add --force src
git commit -q -m "Minecraft $ $(date)" --author="Vanilla <>"

while IFS= read -r -d '' file
do
  _patchFile="$file"
  file="$(echo "$file" | cut -d "/" -f2- | cut -d. -f1).java"

  echo "Patching $file < ${_patchFile}"
  strip_cr "${decompilation_nms}/${file}" > /dev/null

  "$patch" -s -d src/main/java -p 1 < "${_patchFile}"
done < <(find nms-patches -type f -print0)

git add --force src
git commit -q -m "CraftBukkit $ $(date)" --author="CraftBukkit <>"
git -c advice.detachedHead=false checkout -f HEAD~2
