# syntax=docker/dockerfile:1.4
FROM debian:bookworm AS builder
ARG TARGETARCH
RUN apt-get update && apt-get install -y curl
WORKDIR /workspace
COPY download-workerd.sh ./
RUN ARCH=${TARGETARCH} ./download-workerd.sh

FROM gcr.io/distroless/cc-debian12:nonroot
COPY --from=builder /workspace/bin/workerd /usr/local/bin/workerd
ENTRYPOINT ["workerd"]
