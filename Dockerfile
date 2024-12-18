# syntax=docker/dockerfile:1

ARG ALPINETAG
ARG ARCH
FROM ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-${ARCH} as cache

ARG ALPINETAG
FROM alpine:${ALPINETAG} as builder

ENV PACKAGER_PRIVKEY="/config/.abuild/ig.rsa"
ARG PRIVKEY
ARG ALPINETAG

COPY . /config/aports
COPY --from=cache /aports/v${ALPINETAG} /config/packages/ig

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    alpine-sdk \
    curl \
    sudo \
    aports-build && \
  echo "**** create abc user and setup sudo ****" && \
  adduser -h /config -D abc && \
  echo 'abc ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers && \
  addgroup abc abuild && \
  echo "**** configure abuild/copy keys ****" && \
  mkdir -p /config/.abuild/ && \
  echo -e "$PRIVKEY" >/config/.abuild/ig.rsa && \
  PUBKEY=$(curl -s https://packages.imagegenius.io/ig.rsa.pub) && \
  echo -e "$PUBKEY" >/config/.abuild/ig.rsa.pub && \
  echo -e "$PUBKEY" >/etc/apk/keys/ig.rsa.pub && \
  echo "**** run buildrepo ****" && \
  abuild-apk update && \
  apk update && \
  chown -R abc:abc /config && \
  su abc -c "buildrepo -p ig -d /config/packages"

FROM scratch

ARG ALPINETAG
COPY --from=builder /config/packages/ig /aports/v${ALPINETAG}
