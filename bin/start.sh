#!/bin/sh

SSHD_KEY_LOC=/config/ssh/keys

GIT_PUBLIC=/opt/git/public
GIT_PRIVATE=/opt/git/private

if [ ! -d "$GIT_PUBLIC" ]
then
    echo "Public git directory not mounted - please --mount this directory" >&2
    exit 4
fi
if [ ! -d "$GIT_PRIVATE" ]
then
    echo "Private git directory not mounted - please --mount this directory" >&2
    exit 5
fi

if [ ! -d $SSHD_KEY_LOC ]
then
    install --directory $SSHD_KEY_LOC
fi

addgroup git

for SSHD_USER in gituser gitreader
do
    if ! getent passwd ${SSHD_USER} > /dev/null
    then
        adduser -s /usr/bin/git-shell -D -G git ${SSHD_USER}
        passwd -d ${SSHD_USER}
        install --owner ${SSHD_USER} --group git --mode 700 --directory "/home/${SSHD_USER}/.ssh"
    fi
    if [ -f "${SSHD_KEY_LOC}/${SSHD_USER}" ]
    then
        install --owner ${SSHD_USER} --group git --mode 700 "${SSHD_KEY_LOC}/${SSHD_USER}" "/home/${SSHD_USER}/.ssh/authorized_keys"
    else
        echo "NOTE: user ${SSHD_USER} has no authorized_keys file - access will not be possible. Empty file created."
        touch "${SSHD_KEY_LOC}/${SSHD_USER}" "/home/${SSHD_USER}/.ssh/authorized_keys"
    fi
done

for TYPE in ecdsa rsa dsa ed25519
do
    config_key=$SSHD_KEY_LOC/ssh_host_${TYPE}_key
    local_key=/etc/ssh/ssh_host_${TYPE}_key
    # If not already in the config partition, copy them there
    if [ ! -f $config_key ]; then
        echo Generating $TYPE SSH key...
        ssh-keygen -q -f $config_key -N '' -t $TYPE
    fi
    rm -f ${local_key}*
    ln -s ${config_key}* /etc/ssh
done

if [ ! -d /var/run/sshd ]
then
    install --directory /var/run/sshd
fi

[ ! -d /run/fcgiwrap ] || install --directory --owner fcgiwrap --group www-data /run/fcgiwrap

# fcgiwrap for gitweb
FCGIWRAP_USER=fcgiwrap
FCGIWRAP_GRP=www-data
FCGIWRAP_SOCK=/run/fcgiwrap/fcgiwrap.sock
[ -d /run/fcgiwrap ] || mkdir -p /run/fcgiwrap
[ -S "${FCGIWRAP_SOCK}" ] && rm -f "${FCGIWRAP_SOCK}"
chown ${FCGIWRAP_USER}:${FCGIWRAP_GRP} /run/fcgiwrap
echo Starting fcgiwrap...
sudo -u $FCGIWRAP_USER $(which fcgiwrap) -c $(nproc) -s unix:"${FCGIWRAP_SOCK}" &
sleep 5
[ -S "${FCGIWRAP_SOCK}" ] || exit 3
chmod g+w "${FCGIWRAP_SOCK}"

# nginx
if [ -f /config/httpd-default.conf ]
then
    cp /config/httpd-default.conf /etc/nginx/http.d/default.conf
else
    sed -i 's/\$SERVER_NAME/'$(hostname -f)'/g' /etc/nginx/http.d/default.conf
    cp /etc/nginx/http.d/default.conf /config/httpd-default.conf
fi
[ -f /config/httpd-ssl.conf ] && cp /config/httpd-ssl.conf /etc/nginx/http.d/ssl.conf
[ -f /config/ssl.crt ] && install -o root -g root -m 0644 /config/ssl.crt /etc/ssl/certs/httpd.crt
[ -f /config/ssl.key ] && install -o root -g root -m 0640 /config/ssl.key /etc/ssl/private/httpd.key
echo Starting nginx...
nginx -c /etc/nginx/nginx.conf || exit 1

# sshd
echo Starting sshd...
/usr/sbin/sshd -e || exit 2

# SSH authorised keys update
echo Starting ssh authorised keys update...
while sleep 60
do
    for SSHD_USER in gituser gitreader
    do
        install --owner ${SSHD_USER} --group git --mode 700 "${SSHD_KEY_LOC}/${SSHD_USER}" /home/${SSHD_USER}/.ssh/authorized_keys
    done
done
