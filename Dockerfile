# syntax=docker/dockerfile:1.4
FROM debian:bookworm-slim AS base

FROM base AS builder
ARG TARGETARCH
RUN apt-get update
RUN apt-get install -y build-essential git lsb-release curl wget software-properties-common gnupg python3 python3-distutils libunwind-14 libc++abi1-14 libc++1-14 libc++-14-dev
RUN wget https://apt.llvm.org/llvm.sh && \
  chmod +x llvm.sh && \
  ./llvm.sh 14
RUN curl -L https://github.com/bazelbuild/bazelisk/releases/download/v1.17.0/bazelisk-linux-${TARGETARCH} -o /usr/local/bin/bazelisk && \
  chmod +x /usr/local/bin/bazelisk
RUN mkdir -p /workspace && \
  curl -L https://github.com/Dcard/workerd/archive/4bde46d5729f87b5f6a082420f0b5c2c9e8f8f34.tar.gz | tar -zx --strip-component=1 -C /workspace
WORKDIR /workspace
RUN echo -e "\n\
build:linux --action_env=CC=/usr/lib/llvm-14/bin/clang --action_env=CXX=/usr/lib/llvm-14/bin/clang++\n\
build:linux --host_action_env=CC=/usr/lib/llvm-14/bin/clang --host_action_env=CXX=/usr/lib/llvm-14/bin/clang++\n\
" >> .bazelrc
RUN --mount=type=cache,target=/root/.cache/bazelisk \
  --mount=type=cache,target=/root/.cache/bazel \
  bazelisk build --config=thin-lto //src/workerd/server:workerd && \
  cp bazel-bin/src/workerd/server/workerd /usr/local/bin/workerd

FROM base
COPY --from=builder /usr/local/bin/workerd /usr/local/bin/workerd
ENTRYPOINT ["workerd"]
