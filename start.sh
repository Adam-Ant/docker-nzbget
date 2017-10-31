#!/bin/sh
set -e

conf_file="/config/nzbget.conf"

if [ ! -f "$conf_file" ]; then
    cp /nzbget/nzbget.conf $conf_file
    chown $UID:$GID $conf_file

    # Set some sane logging defaults
    sed -i 's|\(^LogFile=\).*|\1/config/nzbget.log|;
            s|\(^OutputMode=\).*|\1log|' $conf_file

    echo "Created default config file at $conf_file"
fi

if ! su-exec $UID:$GID sh -c 'test -w /config'; then
    chown $UID:$GID /config
fi

# Ensure nzbget directory is writeable by the running user
chown -R $UID:$GID /nzbget

exec su-exec $UID:$GID $@
