#!/bin/bash
set -euo pipefail

PS1="$"
WORKING_DIR="$1"

# Do not run this script directly

wget_dir="${WORKING_DIR}/tmp"

SPECIALSOURCE_GIT_REF=b140ee56f3d8c7c9b6ecf559cf091a543e0c762c
SPECIALSOURCE2_GIT_REF=b0473ffae9fb0fd8ec2bd0835e7b86aa21aae9f6

alias git="git -c commit.gpgsign=false"

patch=$(which patch 2>/dev/null)
if [[ "x$patch" == "x" ]]; then
  patch="${WORKING_DIR}/Panda/base/hctap.exe"
fi

cd "${WORKING_DIR}/SpecialSource"
git reset --hard $SPECIALSOURCE_GIT_REF
git clean -fd
"$patch" pom.xml < "${WORKING_DIR}/patches/SpecialSource/pom.xml.patch"
mvn clean package
rm -rf "${wget_dir}/SpecialSource.jar"
cp "target/SpecialSource.jar" "${wget_dir}/SpecialSource.jar"
git reset --hard $SPECIALSOURCE_GIT_REF

cd "${WORKING_DIR}/SpecialSource2"
git reset --hard $SPECIALSOURCE2_GIT_REF
git clean -fd
"$patch" _specialsource_2_decompile.sh < "${WORKING_DIR}/patches/SpecialSource2/_specialsource_2_decompile.sh.patch"
./build.sh
rm -rf "${wget_dir}/SpecialSource-2.jar"
cp "ss2/target/SpecialSource-2.jar" "${wget_dir}/SpecialSource-2.jar"
git reset --hard $SPECIALSOURCE2_GIT_REF
