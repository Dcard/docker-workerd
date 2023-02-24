# syntax=docker/dockerfile:1.4
FROM debian:bookworm-slim AS base

FROM base AS install
ARG TARGETARCH
RUN apt-get update && apt-get install -y curl
WORKDIR /workspace
COPY download-workerd.sh ./
RUN ARCH=${TARGETARCH} ./download-workerd.sh

FROM base
RUN apt-get update && apt-get install -y libc++-dev libc++abi-dev
COPY --from=install /workspace/bin/workerd /usr/local/bin/workerd
CMD ["workerd"]
