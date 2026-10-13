FROM rockylinux/rockylinux:10

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

# Install dependencies for rockylinux
RUN dnf update -y && \
    dnf install 'dnf-command(config-manager)' -y && \
    dnf config-manager --set-enabled crb && \
    dnf install epel-release -y && \
    dnf install cracklib-devel cyrus-sasl-devel gcc groff krb5-devel libevent-devel libsodium-devel libtool-ltdl-devel make openssl openssl-devel pandoc systemd -y && \
    dnf install rpm-build rpmdevtools git -y && \
    dnf clean all

COPY run/build-packages.sh /opt

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD [ "/bin/bash", "/opt/build-packages.sh"]

