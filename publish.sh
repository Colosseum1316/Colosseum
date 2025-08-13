#!/bin/bash

set -e

PS1="$"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd ${SCRIPT_DIR}
cd ColosseumSpigot-API

export MAVEN_OPTS=-Djansi.force=true
mvn -B -V -e -s "${SCRIPT_DIR}/settings.xml" -ntp -Dstyle.color=always \
  -DaltDeploymentRepository=github::default::https://maven.pkg.github.com/${GITHUB_REPOSITORY}/ \
  clean deploy
