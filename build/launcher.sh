#!/bin/sh

# Print info
echo "
=======================================================================
USER INFO:

UID: $PUID
GID: $PGID

=======================================================================
"
# Set user and group ID to sdtdserver user
echo "Setting UID/GID"
groupmod -o -g "$PGID" sdtd  > /dev/null
usermod -o -u "$PUID" sdtd  > /dev/null

# Apply owner to the folder to avoid errors
chown -R sdtd:sdtd /home/sdtd

# start cron
/etc/init.d/cron start

# invoke startup as user sdtd
exec gosu sdtd "$@"
