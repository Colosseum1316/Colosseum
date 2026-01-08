#!/bin/bash

# References:
# https://github.com/hpfxd/PandaSpigot
# https://github.com/PaperMC/Paper-archive

PS1="$"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

alias git="git -c commit.gpgsign=false -c core.safecrlf=false -c advice.detachedHead=false"

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

if sed --version >/dev/null 2>&1; then
  function strip_cr {
    sed -i -- "s/\r//" "$@"
  }
else
  function strip_cr {
    sed -i "" "s/$(printf '\r')//" "$@"
  }
fi

function colosseum_dirs_reset {
  set -x
  rm -rf "${SCRIPT_DIR}/Panda"
  rm -rf "${SCRIPT_DIR}/SpecialSource"
  rm -rf "${SCRIPT_DIR}/SpecialSource2"
  rm -rf "${SCRIPT_DIR}/ColosseumSpigot-API"
  rm -rf "${SCRIPT_DIR}/ColosseumSpigot-Server"
  rm -rf "${SCRIPT_DIR}/mc-dev"
  set +x
}

function colosseum_dirs_full_reset {
  colosseum_dirs_reset

  set -x

  cd ${SCRIPT_DIR}
  rm -rf "${SCRIPT_DIR}/tmp"
  git submodule update --init -- SpecialSource SpecialSource2 Panda

  set +x
}

function _init {
  set -x
  cd ${SCRIPT_DIR}
  git submodule update --init
  cd Panda
  git submodule update --init
  cd base/Paper
  git submodule update --init -- Bukkit CraftBukkit BuildData
  set +x
}

case "$1" in
  "r" | "re" | "reset")
  colosseum_dirs_reset ; _init ; exit ;
  ;;
  "fr" | "full_reset" )
  colosseum_dirs_full_reset ; _init ; exit ;
  ;;
  "i" | "init")
  _init ; exit ;
  ;;
esac

_init

minecraft_version="$(cat "${SCRIPT_DIR}/Panda/base/Paper/BuildData/info.json" | grep minecraftVersion | cut -d '"' -f 4)"
minecraft_server_jar_download_url="https://launcher.mojang.com/v1/objects/5fafba3f58c40dc51b5c3ca72a98f62dfdae1db7/server.jar"
minecraft_server_jar_hash=$(cat "${SCRIPT_DIR}/Panda/base/Paper/BuildData/info.json" | grep minecraftHash | cut -d '"' -f 4)

decompilation_mcdev_dir="${SCRIPT_DIR}/mc-dev"
decompilation_spigot_dir="${decompilation_mcdev_dir}/spigot"
decompilation_classes_dir="${decompilation_mcdev_dir}/classes"
_nms="net/minecraft/server"
decompilation_nms="${decompilation_spigot_dir}/${_nms}"
wget_dir="${SCRIPT_DIR}/tmp"

decompilation_server_jar="${decompilation_mcdev_dir}/${minecraft_version}.jar"
decompilation_server_jar_cl="${decompilation_mcdev_dir}/${minecraft_version}-cl.jar"
decompilation_server_jar_m="${decompilation_mcdev_dir}/${minecraft_version}-m.jar"
decompilation_server_jar_mapped="${decompilation_mcdev_dir}/${minecraft_version}-mapped.jar"

decompilation_accesstransforms="${SCRIPT_DIR}/Panda/base/Paper/BuildData/mappings/"$(cat "${SCRIPT_DIR}/Panda/base/Paper/BuildData/info.json" | grep accessTransforms | cut -d '"' -f 4)
decompilation_classmappings="${SCRIPT_DIR}/Panda/base/Paper/BuildData/mappings/"$(cat "${SCRIPT_DIR}/Panda/base/Paper/BuildData/info.json" | grep classMappings | cut -d '"' -f 4)
decompilation_membermappings="${SCRIPT_DIR}/Panda/base/Paper/BuildData/mappings/"$(cat "${SCRIPT_DIR}/Panda/base/Paper/BuildData/info.json" | grep memberMappings | cut -d '"' -f 4)
decompilation_packagemappings="${SCRIPT_DIR}/Panda/base/Paper/BuildData/mappings/"$(cat "${SCRIPT_DIR}/Panda/base/Paper/BuildData/info.json" | grep packageMappings | cut -d '"' -f 4)

set -x
mkdir -p "${wget_dir}" || true
mkdir -p "${decompilation_mcdev_dir}" || true
mkdir -p "${decompilation_spigot_dir}" || true
set +x

if [[ ! -f "${wget_dir}/server.jar" ]]; then
  echo "Downloading vanilla server jar"
  set -e
  wget --progress=dot:giga -O "${wget_dir}/server.jar" "${minecraft_server_jar_download_url}"
  set +e
fi

set -e
cp "${wget_dir}/server.jar" "${decompilation_server_jar}"
set +e

_checksum="$(md5sum "${decompilation_server_jar}" | cut -d ' ' -f 1)"
if [[ "${_checksum}" != "${minecraft_server_jar_hash}" ]]; then
  echo "The MD5 checksum of the downloaded server jar does not match!!!"
  exit 1
fi

cd ${SCRIPT_DIR}

function _cleanup_patches {
  cd "$1"
  for _patch in $(ls *.patch); do
    echo "${_patch}"
    local diffs=$(git diff --staged "${_patch}" | grep --color=none -E "^(\+|-)" | grep --color=none -Ev "(--- a|\+\+\+ b|^.index)")

    if [[ "x$diffs" == "x" ]] ; then
      git reset HEAD "${_patch}" >/dev/null
      git checkout -- "${_patch}" >/dev/null
    fi
  done
}

# $target has changes based on $what. Generate patches and save to $patch_folder
function _save_patches {
  local what=$1
  local what_name=$(basename "$what")
  local target=$2
  local patch_folder=$3
  echo "Formatting patches for ${what_name}"

  cd "${SCRIPT_DIR}/${patch_folder}"
  if [[ -d "${SCRIPT_DIR}/${target}/.git/rebase-apply" ]]; then
    # in middle of a rebase, be smarter
    local orderedfiles=$(find . -name "*.patch" | sort)
    for i in $(seq -f "%04g" 1 1 "$(cat "${SCRIPT_DIR}/${target}/.git/rebase-apply/last")")
    do
      if [[ $i -lt "$(cat "${SCRIPT_DIR}/${target}/.git/rebase-apply/next")" ]]; then
        rm -rf $(echo "$orderedfiles{@}" | sed -n "${i}p")
      fi
    done
  else
    rm -rf *.patch
  fi

  cd "${SCRIPT_DIR}/${target}"

  git format-patch --zero-commit --full-index --no-signature --no-stat -N -o "${SCRIPT_DIR}/${patch_folder}/" upstream/upstream >/dev/null
  cd "${SCRIPT_DIR}"
  git add --force -A "${SCRIPT_DIR}/${patch_folder}"
  _cleanup_patches "${SCRIPT_DIR}/${patch_folder}"
  echo "Patches saved for ${what_name} to ${patch_folder}"
}

# $what at $branch + $patch_folder -> $target
function _apply_patches {
  local what=$1
  local what_name=$(basename "$what")
  local target=$2
  local branch=$3
  local patch_folder=$4

  cd ${what}
  git fetch
  git branch -f upstream "$branch" >/dev/null

  if [[ ! -d "${target}" ]]; then
    git clone "$what" "$target"
  fi
  cd ${target}

  echo "Resetting ${target} to ${what_name}"
  git remote rm origin > /dev/null 2>&1
  git remote rm upstream > /dev/null 2>&1
  git remote add upstream "${what}" >/dev/null 2>&1
  git checkout master 2>/dev/null || git checkout -b master
  git fetch upstream >/dev/null 2>&1
  git reset --hard upstream/upstream

  echo "  Applying patches to ${target}"

  local statusfile=".git/patch-apply-failed"
  rm -rf "$statusfile"
  git am --abort >/dev/null 2>&1

  git am --3way --ignore-whitespace "${patch_folder}/"*.patch

  if [[ "$?" != "0" ]]; then
    echo 1 > "$statusfile"
    echo "  Something did not apply cleanly to ${target}."
    echo "  Please review above details."
    exit 1
  else
    rm -rf "$statusfile"
    echo "  Patches applied cleanly to ${target}"
  fi
}

function colosseum_minecraft_rebuild_patch {
  echo "Rebuilding patch files from current fork state"

  cd ${SCRIPT_DIR}

  _save_patches "Panda/PandaSpigot-API" "ColosseumSpigot-API" "patches/api"
  _save_patches "Panda/PandaSpigot-Server" "ColosseumSpigot-Server" "patches/server"
}

function colosseum_minecraft_apply_patch {
  cd ${SCRIPT_DIR}

  echo "Rebuilding Forked projects"

  cd "Panda/base/Paper"

  local WORKING_DIR="$(pwd)"

  # Apply Spigot
  (
    _apply_patches "${WORKING_DIR}/Bukkit" "${WORKING_DIR}/Spigot-API" HEAD "${WORKING_DIR}/Bukkit-Patches" &&
    _apply_patches "${WORKING_DIR}/CraftBukkit" "${WORKING_DIR}/Spigot-Server" patched "${WORKING_DIR}/CraftBukkit-Patches"
  ) || (
    echo "Failed to apply Spigot Patches!!!"
    exit 1
  ) || exit 1

  # Apply Paper
  (
    _apply_patches "${WORKING_DIR}/Spigot-API" "${WORKING_DIR}/PaperSpigot-API" HEAD "${WORKING_DIR}/Spigot-API-Patches" &&
    _apply_patches "${WORKING_DIR}/Spigot-Server" "${WORKING_DIR}/PaperSpigot-Server" HEAD "${WORKING_DIR}/Spigot-Server-Patches"
  ) || (
    echo "Failed to apply Paper Patches!!!"
    exit 1
  ) || exit 1

  unset ${WORKING_DIR}
  cd ${SCRIPT_DIR}

  echo "Importing MC Dev"

  find "${decompilation_nms}" -type f -name "*.java" | while read file; do
    local filename="$(basename "$file")"
    local target="${SCRIPT_DIR}/Panda/base/Paper/PaperSpigot-Server/src/main/java/${_nms}/${filename}"

    set -x
    if [[ ! -f "${target}" ]]; then
      cp "$file" "$target"
    fi
    set +x
  done

  set -x
  cp -rt "${SCRIPT_DIR}/Panda/base/Paper/PaperSpigot-Server/src/main/resources" "${decompilation_spigot_dir}/assets" "${decompilation_spigot_dir}/yggdrasil_session_pubkey.der"
  cd "${SCRIPT_DIR}/Panda/base/Paper/PaperSpigot-Server"
  if [[ "$(git log -1 --oneline)" = *"mc-dev Imports"* ]]; then
    git reset --hard HEAD^
  fi
  rm -rf nms-patches applyPatches.sh makePatches.sh README.md >/dev/null 2>&1
  git add --force . -A >/dev/null 2>&1
  echo -e "mc-dev Imports" | git commit . -q -F -
  set +x

  cd ${SCRIPT_DIR}

  # Apply PandaSpigot
  (
    _apply_patches "${SCRIPT_DIR}/Panda/base/Paper/PaperSpigot-API" "${SCRIPT_DIR}/Panda/PandaSpigot-API" HEAD "${SCRIPT_DIR}/Panda/patches/api" &&
    _apply_patches "${SCRIPT_DIR}/Panda/base/Paper/PaperSpigot-Server" "${SCRIPT_DIR}/Panda/PandaSpigot-Server" HEAD "${SCRIPT_DIR}/Panda/patches/server"
  ) || (
    echo "Failed to apply PandaSpigot Patches!!!"
    exit 1
  ) || exit 1

  # Apply ColosseumSpigot
  (
    _apply_patches "${SCRIPT_DIR}/Panda/PandaSpigot-API" "${SCRIPT_DIR}/ColosseumSpigot-API" HEAD "${SCRIPT_DIR}/patches/api" &&
    _apply_patches "${SCRIPT_DIR}/Panda/PandaSpigot-Server" "${SCRIPT_DIR}/ColosseumSpigot-Server" HEAD "${SCRIPT_DIR}/patches/server"
  ) || (
    echo "Failed to apply ColosseumSpigot Patches!!!"
    exit 1
  ) || exit 1
}

function _prepare_specialsource {
  local SPECIALSOURCE_GIT_REF=b140ee56f3d8c7c9b6ecf559cf091a543e0c762c
  local SPECIALSOURCE2_GIT_REF=b6d5bd7f8a5f7c2a41f1adf96e251650575de103

  cd ${SCRIPT_DIR}

  cd "${SCRIPT_DIR}/SpecialSource"
  git reset --hard ${SPECIALSOURCE_GIT_REF}
  git clean -fd
  patch pom.xml < "${SCRIPT_DIR}/patches/SpecialSource/pom.xml.patch"
  mvn -B -V -e -ntp clean verify
  rm -rf "${wget_dir}/SpecialSource.jar"
  cp "target/SpecialSource.jar" "${wget_dir}/SpecialSource.jar"
  git reset --hard ${SPECIALSOURCE_GIT_REF}

  cd "${SCRIPT_DIR}/SpecialSource2"
  git reset --hard ${SPECIALSOURCE2_GIT_REF}
  git clean -fd
  patch _specialsource_2_decompile.sh < "${SCRIPT_DIR}/patches/SpecialSource2/_specialsource_2_decompile.sh.patch"
  ./build.sh
  rm -rf "${wget_dir}/SpecialSource-2.jar"
  cp "ss2/target/SpecialSource-2.jar" "${wget_dir}/SpecialSource-2.jar"
  git reset --hard ${SPECIALSOURCE2_GIT_REF}
}

function _decompile_nms {
  cd ${SCRIPT_DIR}

  if [[ ! -d "${decompilation_classes_dir}" ]]; then
    echo "Extracting NMS classes"
    mkdir -p "${decompilation_classes_dir}" || true
    cd "${decompilation_classes_dir}"
    if ! jar xf "${decompilation_server_jar_mapped}" "${_nms}" yggdrasil_session_pubkey.der assets; then
      echo "Failed to extract NMS classes!!!"
      exit 1
    fi
  fi

  if [[ -d "${decompilation_nms}" ]]; then
    cp -r "${decompilation_nms}" "${decompilation_spigot_dir}/"
  fi

  if [[ ! -d "${decompilation_nms}" ]]; then
    echo "Decompiling NMS classes"
    java -version
    set -x
    if ! java -jar "${SCRIPT_DIR}/Panda/base/Paper/BuildData/bin/fernflower.jar" -den=1 -dgs=1 -hdc=0 -rbr=0 -asc=1 -udv=0 "${decompilation_classes_dir}" "${decompilation_spigot_dir}"; then
      rm -rf "${decompilation_spigot_dir}/net"
      set +x
      echo "Failed to decompile NMS classes!!!"
      exit 1
    fi
    set +x
  fi

  local _craftbukkit="src/main/java/${_nms}"

  echo "Applying CraftBukkit patches to NMS"

  set -x
  cd "${SCRIPT_DIR}/Panda/base/Paper/CraftBukkit"
  git checkout -B patched HEAD >/dev/null 2>&1
  rm -rf "${_craftbukkit}"
  mkdir -p "${_craftbukkit}"
  set +x

  while IFS= read -r -d '' file
  do
    file="$(echo "${file}" | cut -d "/" -f2- | cut -d. -f1).java"
    cp "${decompilation_nms}/${file}" "${_craftbukkit}/${file}"
  done < <(find nms-patches -type f -print0)
  git add --force src
  git commit -q -m "Minecraft $ $(date)" --author="Vanilla <>"

  while IFS= read -r -d '' file
  do
    local _patchFile="${file}"
    file="$(echo "${file}" | cut -d "/" -f2- | cut -d. -f1).java"

    echo "Patching ${file} < ${_patchFile}"
    strip_cr "${decompilation_nms}/${file}" > /dev/null
    patch -s -d src/main/java -p 1 < "${_patchFile}"
  done < <(find nms-patches -type f -print0)

  unset file

  git add --force src
  git commit -q -m "CraftBukkit $ $(date)" --author="CraftBukkit <>"
  git checkout -f HEAD~2
}

function colosseum_minecraft_decompile {
  _prepare_specialsource

  java -version

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

  _decompile_nms
}

case "$1" in
  "b" | "build")
  colosseum_minecraft_decompile ;
  colosseum_minecraft_apply_patch ;
  ./gradlew test build
  ;;
  "_d" | "_decompile")
  colosseum_minecraft_decompile ;
  ;;
  "_a" | "_apply_patch")
  colosseum_minecraft_apply_patch ;
  ;;
  "p" | "rebuild_patch")
  colosseum_minecraft_rebuild_patch ;
  ;;
  *)
  echo "(b)uild" ;
  echo "(_d)ecompile" ;
  echo "(_a)pply_patch" ;
  echo "(r)eset" ;
  echo "(r)ebuild_(p)atch" ;
  echo "(f)ull_(r)eset" ;
  echo "(i)nit" ;
  exit 1 ;
  ;;
esac
