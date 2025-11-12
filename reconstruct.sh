#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd $SCRIPT_DIR

./_colosseum_spigot_patch_rebuild.sh "$SCRIPT_DIR"
