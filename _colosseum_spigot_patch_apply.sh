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
_nms="net/minecraft/server"
decompilation_nms="${decompilation_spigot_dir}/${_nms}"

alias git="git -c commit.gpgsign=false"

# $what at $branch + $patch_folder -> $target
function applyPatch {
  local what=$1
  local what_name=$(basename "$what")
  local target=$2
  local branch=$3
  local patch_folder=$4

  cd "${WORKING_DIR}/${what}"
  git fetch
  git branch -f upstream "$branch" >/dev/null

  cd "$WORKING_DIR"
  if [[ ! -d "${WORKING_DIR}/${target}" ]]; then
      git clone "$what" "$target"
  fi
  cd "${WORKING_DIR}/${target}"

  echo "Resetting ${target} to ${what_name}"
  git remote rm origin > /dev/null 2>&1
  git remote rm upstream > /dev/null 2>&1
  git remote add upstream "${WORKING_DIR}/${what}" >/dev/null 2>&1
  git checkout master 2>/dev/null || git checkout -b master
  git fetch upstream >/dev/null 2>&1
  git reset --hard upstream/upstream

  echo "  Applying patches to ${target}"

  local statusfile=".git/patch-apply-failed"
  rm -rf "$statusfile"
  git am --abort >/dev/null 2>&1

  # Special case Windows handling because of ARG_MAX constraint
  if [[ $windows == "true" ]]; then
    find "${WORKING_DIR}/${patch_folder}/"*.patch -print0 | xargs -0 git am --3way --ignore-whitespace
  else
    git am --3way --ignore-whitespace "${WORKING_DIR}/${patch_folder}/"*.patch
  fi

  if [[ "$?" != "0" ]]; then
    echo 1 > "$statusfile"
    echo "  Something did not apply cleanly to ${target}."
    echo "  Please review above details and finish the apply then"
    echo "  save the changes with _minecraft_spigot_patch_rebuild.sh"

    # On Windows, finishing the patch apply will only fix the latest patch
    # users will need to rebuild from that point and then re-run the patch
    # process to continue
    if [[ $windows == "true" ]]; then
      echo ""
      echo "  Because you're on Windows you'll need to finish the AM,"
      echo "  rebuild all patches, and then re-run the patch apply again."
      echo "  Consider using the scripts with Windows Subsystem for Linux."
    fi

    exit 1
  else
    rm -rf "$statusfile"
    echo "  Patches applied cleanly to ${target}"
  fi
}

echo "Rebuilding Forked projects"

# Move into Paper dir
WORKING_DIR="${WORKING_DIR}/Panda/base/Paper"
cd "${WORKING_DIR}"

# Apply Spigot
(
  applyPatch Bukkit Spigot-API HEAD Bukkit-Patches &&
  applyPatch CraftBukkit Spigot-Server patched CraftBukkit-Patches
) || (
  echo "Failed to apply Spigot Patches!!!"
  exit 1
) || exit 1

# Apply Paper
(
  applyPatch Spigot-API PaperSpigot-API HEAD Spigot-API-Patches &&
  applyPatch Spigot-Server PaperSpigot-Server HEAD Spigot-Server-Patches
) || (
  echo "Failed to apply Paper Patches!!!"
  exit 1
) || exit 1

# Move out of Paper
WORKING_DIR="$1"
cd "${WORKING_DIR}"

echo "Importing MC Dev"

find "${decompilation_nms}" -type f -name "*.java" | while read file; do
  filename="$(basename "$file")"
  target="${WORKING_DIR}/Panda/base/Paper/PaperSpigot-Server/src/main/java/${_nms}/${filename}"

  if [[ ! -f "${target}" ]]; then
    cp "$file" "$target"
  fi
done

cp -rt "${WORKING_DIR}/Panda/base/Paper/PaperSpigot-Server/src/main/resources" "${decompilation_spigot_dir}/assets" "${decompilation_spigot_dir}/yggdrasil_session_pubkey.der"
cd "${WORKING_DIR}/Panda/base/Paper/PaperSpigot-Server"
if [[ "$(git log -1 --oneline)" = *"mc-dev Imports"* ]]; then
  git reset --hard HEAD^
fi
rm -rf nms-patches applyPatches.sh makePatches.sh README.md >/dev/null 2>&1
git add --force . -A >/dev/null 2>&1
echo -e "mc-dev Imports" | git commit . -q -F -

# Apply PandaSpigot
(
  applyPatch "Panda/base/Paper/PaperSpigot-API" "Panda/PandaSpigot-API" HEAD "Panda/patches/api" &&
  applyPatch "Panda/base/Paper/PaperSpigot-Server" "Panda/PandaSpigot-Server" HEAD "Panda/patches/server"
) || (
  echo "Failed to apply PandaSpigot Patches"
  exit 1
) || exit 1

cd "${WORKING_DIR}"

(
  applyPatch "Panda/PandaSpigot-API" "ColosseumSpigot-API" HEAD "patches/api" &&
  applyPatch "Panda/PandaSpigot-Server" "ColosseumSpigot-Server" HEAD "patches/server"
) || (
  echo "Failed to apply Colosseum Patches"
  exit 1
) || exit 1
