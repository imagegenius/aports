ARG ALPINETAG
ARG ARCH
FROM ghcr.io/imagegenius/aports-${ALPINETAG}-cache:${ARCH} as cache

ARG ALPINETAG
FROM alpine:${ALPINETAG} as builder

ENV PACKAGER_PRIVKEY="/config/.abuild/ig.rsa"
ARG PRIVKEY

COPY --from=cache / /config/packages/

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    alpine-sdk \
    git \
	sudo \
	bash \
    aports-build && \
  echo "**** create abc user and setup sudo ****" && \
  adduser -h /config -D abc && \
  echo 'abc ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers && \
  addgroup abc abuild && \
  mkdir -p /config/.abuild/ && \
  echo -e "$PRIVKEY" >/config/.abuild/ig.rsa && \
  PUBKEY=$(curl -s https://packages.hyde.services/ig.rsa.pub)
  echo -e "$PUBKEY" >/config/.abuild/ig.rsa.pub && \
  echo -e "$PUBKEY" >/etc/apk/keys/ig.rsa.pub && \
  git clone https://github.com/imagegenius/aports /config/aports && \
  abuild-apk update && \
  apk update && \
  chown -R abc:abc /config && \
  su abc -c "buildrepo -p ig"

FROM scratch

ARG ALPINETAG
COPY --from=builder /config/packages/ /alpine/v${ALPINETAG}