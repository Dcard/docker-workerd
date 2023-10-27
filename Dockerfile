# syntax=docker/dockerfile:1.4
FROM debian:bookworm-slim AS builder
ARG TARGETARCH
RUN apt-get update

# Install build dependencies
RUN apt-get install -y build-essential git lsb-release curl wget software-properties-common gnupg python3 python3-distutils libunwind-14 libc++abi1-14 libc++1-14 libc++-14-dev

# Install LLVM
RUN <<EOT
  wget https://apt.llvm.org/llvm.sh
  chmod +x llvm.sh
  ./llvm.sh 14
EOT

# Install bazelisk
RUN <<EOT
  curl -L https://github.com/bazelbuild/bazelisk/releases/download/v1.17.0/bazelisk-linux-${TARGETARCH} -o /usr/local/bin/bazelisk
  chmod +x /usr/local/bin/bazelisk
EOT

# Download workerd source code
WORKDIR /workspace
RUN curl -L https://github.com/cloudflare/workerd/archive/refs/tags/v1.20231025.0.tar.gz | tar -zx --strip-component=1 -C ./

# Patch workerd
COPY workerd.patch ./
RUN patch -p1 < workerd.patch

# Build workerd
RUN <<EOT
  echo -e "
build:linux --action_env=CC=/usr/lib/llvm-14/bin/clang --action_env=CXX=/usr/lib/llvm-14/bin/clang++
build:linux --host_action_env=CC=/usr/lib/llvm-14/bin/clang --host_action_env=CXX=/usr/lib/llvm-14/bin/clang++
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
