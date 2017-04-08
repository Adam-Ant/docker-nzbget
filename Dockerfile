FROM alpine:3.5
MAINTAINER Adam Dodman <adam.dodman@gmx.com>

ENV UID=236 UNAME=nzbget GID=990 GNAME=media

ADD start.sh /start.sh

RUN chmod +x /start.sh \
 && addgroup -g $GID $GNAME \
 && adduser -SH -u $UID -G $GNAME -s /usr/sbin/nologin $UNAME \
 && apk add --no-cache openssl unrar p7zip python \
 && wget -O nzbget.run `wget -qO- http://nzbget.net/info/nzbget-version-linux.json | sed -n "s/^.*stable-download.*: \"\(.*\)\".*/\1/p"` \
 && sh nzbget.run \
 && ln -sfv /nzbget/nzbget /usr/bin/nzbget \
 && rm -rf /nzbget.run \
 && apk del --no-cache openssl

USER $UNAME

VOLUME ["/config", "/media"]
EXPOSE 6789
CMD ["/start.sh"]
