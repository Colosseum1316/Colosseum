#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd $SCRIPT_DIR

set -x

rm -rf Panda
rm -rf SpecialSource
rm -rf SpecialSource2
rm -rf ColosseumSpigot-API
rm -rf ColosseumSpigot-Server
rm -rf mc-dev
