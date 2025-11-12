#!/bin/bash

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="${SCRIPT_DIR}"

cd $SCRIPT_DIR

./_minecraft_patch_nms.sh "$SCRIPT_DIR"
./_colosseum_spigot_patch_apply.sh "$SCRIPT_DIR"
mvn -B -V -e -ntp -Dstyle.color=always clean package