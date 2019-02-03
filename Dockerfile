FROM spritsail/alpine:3.9

ARG NZBGET_VER=21.0-r2220
ARG CXXFLAGS="-Ofast -pipe -fstack-protector-strong"
ARG LDFLAGS="-Wl,-O1,--sort-common -Wl,-s"

WORKDIR /tmp

RUN apk add --no-cache \
        unrar p7zip \
        libxml2 openssl zlib ca-certificates \
 && apk add --no-cache -t build_deps \
        jq git g++ make autoconf \
        libxml2-dev zlib-dev openssl-dev \
    \
 && git clone https://github.com/nzbget/nzbget.git -b "v${NZBGET_VER}" --depth=1 . \
    # Apply OpenSSL 1.1.1 compatibility patch
 && wget -qO- https://github.com/nzbget/nzbget/commit/8a59079627650c7cc3ef2308b1de54c08254a849.patch | git apply \
    # Apply OpenSSL no-comp patch for Alpine 3.9
 && wget -qO- https://github.com/nzbget/nzbget/commit/fa57474d784f28050f0027f796cab8621946e082.patch | git apply \
    \
 && ./configure \
        --disable-dependency-tracking \
        --disable-curses \
 && make -j$(nproc 2>/dev/null || grep processor /proc/cpuinfo | wc -l || echo 1) \
    \
 && sed -i 's|\(^AppDir=\).*|\1/nzbget|; \
            s|\(^WebDir=\).*|\1/${AppDir}/webui|; \
            s|\(^MainDir=\).*|\1/downloads|; \
            s|\(^LogFile=\).*|\1/config/nzbget.log|; \
            s|\(^ConfigTemplate=\).*|\1/${AppDir}/nzbget.conf|; \
            s|\(^OutputMode=\).*|\1loggable|' nzbget.conf \
 && sed -i "s|\\(^UnrarCmd=\\).*|\\1$(which unrar)|; \
            s|\\(^SevenZipCmd=\\).*|\\1$(which 7z)|; \
            s|\\(^CertStore=\\).*|\\1/etc/ssl/certs/ca-certificates.crt|; \
            s|\\(^CertCheck=\\).*|\\1yes|" nzbget.conf \
 && mkdir /nzbget /downloads \
 && mv nzbget nzbget.conf webui COPYING /nzbget \
 && chmod g+rw /nzbget \
 && ln -sfv ../../nzbget/nzbget /usr/bin \
    \
 && find /tmp -mindepth 1 -delete \
 && apk del --no-cache build_deps

# ~~~~~~~~~~~~~~~~

ENV SUID=904 SGID=900
ENV NZBGET_CONF_FILE="/config/nzbget.conf"

LABEL maintainer="Spritsail <nzbget@spritsail.io>" \
      org.label-schema.name="NZBGet" \
      org.label-schema.url="https://nzbget.net/" \
      org.label-schema.description="NZBGet - the efficient Usenet downloader" \
      org.label-schema.version=${NZBGET_VER} \
      io.spritsail.version.nzbget=${NZBGET_VER}

WORKDIR /nzbget

EXPOSE 6789
VOLUME ["/config", "/downloads"]
ENTRYPOINT ["/sbin/tini", "--"]
CMD set -e; \
    if [ ! -f "$NZBGET_CONF_FILE" ]; then \
        install -m 644 -o $SUID -g $SGID /nzbget/nzbget.conf $NZBGET_CONF_FILE; \
        echo "Created default config file at $NZBGET_CONF_FILE"; \
    fi; \
    \
    su-exec -e test -w /config || chown $SUID:$SGID /config; \
    su-exec -e test -w /downloads || chown $SUID:$SGID /downloads; \
    # Ensure nzbget directory is writeable by the running user
    chgrp -R $SGID /nzbget; \
    \
    exec su-exec -e nzbget -c $NZBGET_CONF_FILE -s -o OutputMode=log

