#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="${SCRIPT_DIR}"

cd $SCRIPT_DIR

decompilation_mcdev_dir="${WORKING_DIR}/mc-dev"
decompilation_spigot_dir="${decompilation_mcdev_dir}/spigot"
decompilation_nms="${decompilation_spigot_dir}/net/minecraft/server"

rm -rf "${decompilation_nms}"

./_minecraft_jar_decompile.sh "$SCRIPT_DIR"