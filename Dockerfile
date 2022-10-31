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

COPY bin/start.sh /opt/start.sh
COPY etc/httpd-default.conf /etc/nginx/http.d/default.conf
COPY etc/gitweb.conf /etc/gitweb.conf

EXPOSE ${SSHD_PORT}
EXPOSE ${HTTP_PORT}
EXPOSE ${HTTPS_PORT}

CMD ["/opt/start.sh"]
