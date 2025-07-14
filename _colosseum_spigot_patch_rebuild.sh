#!/bin/bash

# References:
# https://github.com/hpfxd/PandaSpigot
# https://github.com/PaperMC/Paper-archive

# Do not run this script directly

PS1="$"
WORKING_DIR="$1"

alias git="git -c commit.gpgsign=false -c core.safecrlf=false"

function cleanupPatches {
  cd "$1"
  for _patch in $(ls *.patch); do
    echo "${_patch}"
    diffs=$(git diff --staged "${_patch}" | grep --color=none -E "^(\+|-)" | grep --color=none -Ev "(--- a|\+\+\+ b|^.index)")

    if [[ "x$diffs" == "x" ]] ; then
      git reset HEAD "${_patch}" >/dev/null
      git checkout -- "${_patch}" >/dev/null
    fi
  done
}

# $target has changes based on $what. Generate patches and save to $patch_folder
function savePatches {
  local what=$1
  local what_name=$(basename "$what")
  local target=$2
  local patch_folder=$3
  echo "Formatting patches for ${what}"

  cd "${WORKING_DIR}/${patch_folder}/"
  if [[ -d "${WORKING_DIR}/${target}/.git/rebase-apply" ]]; then
    # in middle of a rebase, be smarter
    orderedfiles=$(find . -name "*.patch" | sort)
    for i in $(seq -f "%04g" 1 1 "$(cat "${WORKING_DIR}/${target}/.git/rebase-apply/last")")
    do
      if [[ $i -lt "$(cat "${WORKING_DIR}/${target}/.git/rebase-apply/next")" ]]; then
        rm -rf $(echo "$orderedfiles{@}" | sed -n "${i}p")
      fi
    done
  else
    rm -rf *.patch
  fi

  cd "${WORKING_DIR}/${target}"

  git format-patch --zero-commit --full-index --no-signature --no-stat -N -o "${WORKING_DIR}/${patch_folder}/" upstream/upstream >/dev/null
  cd "${WORKING_DIR}"
  git add --force -A "${WORKING_DIR}/${patch_folder}"
  cleanupPatches "${WORKING_DIR}/${patch_folder}"
  echo "Patches saved for ${what} to ${patch_folder}/"
}

echo "Rebuilding patch files from current fork state"

savePatches "${WORKING_DIR}/Panda/PandaSpigot-API" "ColosseumSpigot-API" "patches/api"
savePatches "${WORKING_DIR}/Panda/PandaSpigot-Server" "ColosseumSpigot-Server" "patches/server"
