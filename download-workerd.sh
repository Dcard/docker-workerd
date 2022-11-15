#!/bin/bash

set -euo pipefail

pkg_version=1.20221111.4

if [[ $ARCH == arm* ]]; then
  pkg_arch=arm64
else
  pkg_arch=64
fi

set -x
curl -L https://registry.npmjs.org/@cloudflare/workerd-linux-${pkg_arch}/-/workerd-linux-${pkg_arch}-${pkg_version}.tgz | tar -xz --strip-components 1
