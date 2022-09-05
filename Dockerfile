FROM alpine:3.14

ENV SSHD_PORT=22

RUN apk update \
 && apk add --no-cache \
    openssh-server \
    git \
    gitweb \
    nginx \
    fcgiwrap \
 && sed --in-place --regexp-extended \
    --expression 's|^#(PasswordAuthentication\s+).*|\1no|' \
    --expression 's|^#(GatewayPorts\s+).*|\1yes|' \
    /etc/ssh/sshd_config \
 && rm --recursive --force /tmp/* /var/tmp/*

COPY bin/start.sh /opt/start.sh

VOLUME [ "/opt/config", "/opt/git/public", "/opt/git/private" ]

EXPOSE ${SSHD_PORT}

CMD ["/opt/start.sh"]
