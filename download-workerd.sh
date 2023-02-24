#!/usr/bin/env bash

set -Eeuo pipefail

pkg_version=1.20230221.0
target_path=./bin/workerd

if [[ $ARCH == arm* ]]; then
  pkg_arch=arm64
else
  pkg_arch=64
fi

set -x
mkdir -p "$(dirname $target_path)"
curl -L "https://github.com/cloudflare/workerd/releases/download/v${pkg_version}/workerd-linux-${pkg_arch}" > "$target_path"
chmod +x "$target_path"
