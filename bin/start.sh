#!/bin/sh

SSHD_KEY_LOC=/config/ssh/keys

cleanup()
{
    kill `jobs -p`
    nginx -s stop
    pkill sshd
    rm -f $FCGIWRAP_SOCK

    wait
}

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

for HOST_KEY in /etc/ssh/ssh_host_*_key
do
    TYPE=$(echo ${HOST_KEY##*/} | cut -d_ -f3)
    # If not already in the config partition, copy them there
    if [ ! -f $SSHD_KEY_LOC/ssh_host_${TYPE}_key ]; then
        cp /etc/ssh/ssh_host_${TYPE}_key* $SSHD_KEY_LOC
    fi
    rm -f /etc/ssh/ssh_host_${TYPE}_key*
    ln -s $SSHD_KEY_LOC/ssh_host_${TYPE}_key* /etc/ssh
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
chown ${FCGIWRAP_USER}:${FCGIWRAP_GRP} /run/fcgiwrap
echo Starting fcgiwrap...
sudo -u $FCGIWRAP_USER $(which fcgiwrap) -c $(nproc) -s unix:${FCGIWRAP_SOCK} &
sleep 5
[ -S ${FCGIWRAP_SOCK} ] || exit 3
chmod g+w ${FCGIWRAP_SOCK}

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

# Set the TERM trap so this docker closes gracefully (and hopefully quickly!)

# SSH authorised keys update
echo Starting ssh authorised keys update...
while sleep 60
do
    for SSHD_USER in gituser gitreader
    do
        install --owner ${SSHD_USER} --group git --mode 700 "${SSHD_KEY_LOC}/${SSHD_USER}" /home/${SSHD_USER}/.ssh/authorized_keys
    done
done

trap cleanup EXIT
trap cleanup TERM
