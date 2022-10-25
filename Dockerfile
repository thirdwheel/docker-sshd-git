FROM alpine:3.14

ENV SSHD_PORT=22
ENV HTTP_PORT=80
ENV HTTPS_PORT=443

RUN apk update
RUN apk add --no-cache openssh-server git git-gitweb nginx fcgiwrap sudo perl-cgi
RUN sed --in-place --regexp-extended \
    --expression 's|^#(PasswordAuthentication\s+).*|\1no|' \
    --expression 's|^#(GatewayPorts\s+).*|\1yes|' \
    /etc/ssh/sshd_config
RUN rm -R -f /tmp/* /var/tmp/*
RUN [ -f /etc/ssh/ssh_host_ecdsa_key ] || ssh-keygen -q -f /etc/ssh/ssh_host_ecdsa_key -N '' -t ecdsa
RUN [ -f /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -q -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
RUN [ -f /etc/ssh/ssh_host_dsa_key ] || ssh-keygen -q -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
RUN [ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -q -f /etc/ssh/ssh_host_ed25519_key -N '' -t ed25519

COPY bin/start.sh /opt/start.sh
COPY etc/httpd-default.conf /etc/nginx/http.d/default.conf
COPY etc/gitweb.conf /etc/gitweb.conf

VOLUME [ "/config", "/opt/git/public", "/opt/git/private" ]

EXPOSE ${SSHD_PORT}
EXPOSE ${HTTP_PORT}
EXPOSE ${HTTPS_PORT}

CMD ["/opt/start.sh"]
