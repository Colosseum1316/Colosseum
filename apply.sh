#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set -e

cd $SCRIPT_DIR

alias git="git -c commit.gpgsign=false"
git submodule update --init
cd Panda
git submodule update --init
cd base/Paper
git submodule update --init -- Bukkit CraftBukkit BuildData
cd ${SCRIPT_DIR}

./_minecraft_jar_remap.sh "$SCRIPT_DIR"
./_minecraft_jar_decompile.sh "$SCRIPT_DIR"
./_minecraft_patch_nms.sh "$SCRIPT_DIR"
./_colosseum_spigot_patch_apply.sh "$SCRIPT_DIR"
mvn clean package
