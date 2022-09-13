#!/bin/bash

SSHD_KEY_LOC=/etc/ssh/keys/

addgroup git
addgroup www-data

for SSHD_USER in gituser gitreader
do
    if ! getent passwd ${SSHD_USER} > /dev/null
    then
        adduser -s /usr/bin/git-shell -D -G git ${SSHD_USER}
        install --owner ${SSHD_USER} --group git --mode 700 --directory /home/${SSHD_USER}/.ssh
        if [ -f "${SSHD_KEY_LOC}/${SSHD_USER}" ]
        then
            install --owner ${SSHD_USER} --group ${SSHD_USER} --mode 700 "${SSHD_KEY_LOC}/${SSHD_USER}" /home/${SSHD_USER}/.ssh/authorized_keys
        else
            echo "NOTE: user ${SSHD_USER} has no authorized_keys file - access will not be possible"
        fi
    fi
done

if [ ! -d /config/ssh/keys ]
then
    install --directory /config/ssh/keys
fi

for HOST_KEY in /etc/ssh/ssh_host_*_key
do
    TYPE=$(cut -d_ -f3 <<< ${HOST_KEY##*/})
    if [ ! -f /config/ssh/keys/ssh_host_${TYPE}_key ]; then
        ssh-keygen -q -f /config/ssh/keys/ssh_host_${TYPE}_key -t ${TYPE} -N ''
    fi
    rm --force /etc/ssh/ssh_host_${TYPE}_key*
    ln --symbolic /config/ssh/keys/ssh_host_${TYPE}_key* /etc/ssh
done

if [ ! -d /var/run/sshd ]
then
    install --directory /var/run/sshd
fi

# fcgiwrap for gitweb
FCGIWRAP_USER=fcgiwrap
FCGIWRAP_GRP=www-data
FCGIWRAP_SOCK=/run/fcgiwrap/fcgiwrap.sock
adduser -s /bin/false -S -D -h /var/run/fcgiwrap -G $FCGIWRAP_GRP $FCGIWRAP_USER
[ -d /run/fcgiwrap ] || mkdir -p /run/fcgiwrap
chown ${FCGIWRAP_USER}:${FCGIWRAP_GRP} /run/fcgiwrap
exec su -p $FCGIWRAP_USER -c $(which fcgiwrap)' -c '$(nproc)' -s unix:'${FCGIWRAP_SOCK}
chmod g+w ${FCGIWRAP_SOCK}

# nginx
sed -i 's/\$SERVER_NAME/'$(hostname -f)'/g' /etc/nginx/http.d/default.conf
exec nginx -c /etc/nginx/nginx.conf

# ssh - which will keep this thing alive
exec $(which sshd) -D -e -p ${SSHD_PORT}
