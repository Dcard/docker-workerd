# syntax=docker/dockerfile:1.4
FROM debian:bookworm AS builder
ARG TARGETARCH
ARG LLVM_VERSION=17

RUN <<EOT
  rm -f /etc/apt/apt.conf.d/docker-clean
  echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
EOT

# Install LLVM
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOT
  apt-get update
  apt-get install -y --no-install-recommends curl gnupg git patch ca-certificates python3
  echo "
deb http://apt.llvm.org/bookworm/ llvm-toolchain-bookworm-${LLVM_VERSION} main
deb-src http://apt.llvm.org/bookworm/ llvm-toolchain-bookworm-${LLVM_VERSION} main
" > /etc/apt/sources.list.d/llvm.list
  curl https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
  apt-get update
  apt-get install -y --no-install-recommends \
    llvm-${LLVM_VERSION} \
    lld-${LLVM_VERSION} \
    clang-${LLVM_VERSION} \
    libc++-${LLVM_VERSION}-dev \
    libc++abi-${LLVM_VERSION}-dev \
    libunwind-${LLVM_VERSION}-dev
EOT

# Install bazelisk
RUN <<EOT
  curl -L https://github.com/bazelbuild/bazelisk/releases/download/v1.17.0/bazelisk-linux-${TARGETARCH} -o /usr/local/bin/bazelisk
  chmod +x /usr/local/bin/bazelisk
EOT

# Download workerd source code
WORKDIR /workspace
RUN curl -L https://github.com/cloudflare/workerd/archive/refs/tags/v1.20231030.0.tar.gz | tar -zx --strip-component=1 -C ./

# Patch workerd
COPY workerd.patch ./
RUN patch -p1 < workerd.patch

# Build workerd
RUN <<EOT
  echo "
build:linux --action_env=CC=/usr/lib/llvm-${LLVM_VERSION}/bin/clang --action_env=CXX=/usr/lib/llvm-${LLVM_VERSION}/bin/clang++
build:linux --host_action_env=CC=/usr/lib/llvm-${LLVM_VERSION}/bin/clang --host_action_env=CXX=/usr/lib/llvm-${LLVM_VERSION}/bin/clang++
" >> .bazelrc
EOT

RUN --mount=type=cache,target=/root/.cache/bazelisk \
  --mount=type=cache,target=/root/.cache/bazel <<EOT
  bazelisk build --config=thin-lto -c opt //src/workerd/server:workerd
  strip -S bazel-bin/src/workerd/server/workerd
  cp bazel-bin/src/workerd/server/workerd /usr/local/bin/workerd
EOT

FROM gcr.io/distroless/cc-debian12:nonroot
COPY --from=builder /usr/local/bin/workerd /usr/local/bin/workerd
ENTRYPOINT ["workerd"]
