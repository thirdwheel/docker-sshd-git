FROM bmoorman/ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive

ENV SSHD_PORT=22

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    dnsutils \
    iputils-ping \
    mtr-tiny \
    net-tools \
    openssh-server \
    git \
    gitweb \
 && sed --in-place --regexp-extended \
    --expression 's|^#(PasswordAuthentication\s+).*|\1no|' \
    --expression 's|^#(GatewayPorts\s+).*|\1yes|' \
    /etc/ssh/sshd_config \
 && apt-get autoremove --yes --purge \
 && apt-get clean \
 && rm --recursive --force /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY sshd/ /etc/sshd/

VOLUME /config

EXPOSE ${SSHD_PORT}

CMD ["/etc/sshd/start.sh"]
