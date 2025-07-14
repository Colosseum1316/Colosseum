#!/bin/bash
set -euo pipefail

PS1="$"
WORKING_DIR="$1"

# Do not run this script directly

DOWNLOAD_DIR="${JDK_DOWNLOAD_DIR:-"${WORKING_DIR}/jdks"}"
EXTRACT_DIR="${JDK_EXTRACT_DIR:-"${WORKING_DIR}/.jdk-extracted"}"

function _download_jdk_detect_platform {
  local os="$(uname -s)"
  local arch="$(uname -m)"

  case "$os" in
    Linux) platform_os="linux" ;;
    Darwin) platform_os="mac" ;;
    MINGW*|MSYS*|CYGWIN*) platform_os="windows" ;;
    *) echo "Unsupported OS: $os"; exit 1 ;;
  esac

  case "$arch" in
    x86_64|amd64) platform_arch="x64" ;;
    aarch64|arm64) platform_arch="aarch64" ;;
    *) echo "Unsupported architecture: $arch"; exit 1 ;;
  esac
}

function download_jdk {
  mkdir -p "$DOWNLOAD_DIR"

  local ext archive_url checksum_url

  if [[ "$platform_os" == "windows" ]]; then
    ext="zip"
  else
    ext="tar.gz"
  fi

  cd "${DOWNLOAD_DIR}"

  archive_filename="OpenJDK17U-jdk_${platform_arch}_${platform_os}_hotspot_17.0.15_6.${ext}"
  archive_url="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.15+6/OpenJDK17U-jdk_${platform_arch}_${platform_os}_hotspot_17.0.15_6.${ext}"
  checksum_url="${archive_url}.sha256.txt"
  checksum_filename="${archive_filename}.sha256"

  archive_file="${DOWNLOAD_DIR}/${archive_filename}"

  if [[ ! -f "$checksum_filename" ]]; then
    echo "Downloading $checksum_url"
    wget --progress=dot:mega -O "$checksum_filename" "$checksum_url"
  fi

  if [[ -f "$archive_filename" ]]; then
    echo "Verifying existing archive"
    if sha256sum --check "$checksum_filename"; then
      echo "Archive already downloaded and verified!"
      return
    else
      echo "Checksum failed!"
      rm -rf "$archive_filename"
    fi
  fi

  echo "Downloading $archive_url"
  curl -L --retry 3 --fail -o "$archive_filename" "$archive_url"

  echo "Verifying checksum"
  if sha256sum --check "$checksum_filename"; then
    echo "Checksum verified!"
  else
    echo "Checksum verification failed!!!" >&2
    exit 1
  fi

  cd "${WORKING_DIR}"
}

function extract_jdk {
  if [[ -d "$EXTRACT_DIR" ]]; then
    if "${EXTRACT_DIR}/jdk/bin/java" -version > /dev/null 2>&1; then
      exit 0
    fi
  fi

  rm -rf "$EXTRACT_DIR"
  mkdir -p "$EXTRACT_DIR" || true

  echo "Extracting to: $EXTRACT_DIR"

  if [[ "$archive_file" == *.tar.gz ]]; then
    tar -xzf "$archive_file" -C "$EXTRACT_DIR"
  elif [[ "$archive_file" == *.zip ]]; then
    unzip -q "$archive_file" -d "$EXTRACT_DIR"
  else
    echo "Unknown archive format: $archive_file"
    exit 1
  fi

  local subdir
  subdir=$(find "$EXTRACT_DIR" -maxdepth 1 -type d -name "jdk*" | head -n1)
  [[ -n "$subdir" ]] && mv "$subdir" "$EXTRACT_DIR/jdk"
}

_download_jdk_detect_platform
download_jdk
extract_jdk
