FROM rockylinux/rockylinux:8

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

# Install dependencies for rockylinux
RUN yum update -y && \
    dnf install 'dnf-command(config-manager)' -y && \
    dnf config-manager --set-enabled powertools && \
    yum install epel-release -y && \
    yum install cracklib-devel cyrus-sasl-devel gcc groff krb5-devel libevent-devel libsodium-devel libtool-ltdl-devel make openssl-devel pandoc systemd -y && \
    yum install rpm-build rpmdevtools git -y && \
    yum install bash-completion -y && \
    yum clean all

COPY run/build-packages.sh /opt
COPY run/test-packages.sh /opt

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD [ "/bin/bash", "/opt/build-packages.sh"]

