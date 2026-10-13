FROM centos:7

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

# Install dependencies for rockylinux
RUN sed -i -e 's/^mirrorlist/#mirrorlist/' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i -e 's/^#baseurl/baseurl/' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i -e 's/mirror\.centos\.org/vault.centos.org/' /etc/yum.repos.d/CentOS-*.repo && \
    yum update -y && \
    yum install 'dnf-command(config-manager)' -y && \
    yum install epel-release -y && \
    yum install cracklib-devel cyrus-sasl-devel gcc groff krb5-devel libevent-devel libsodium-devel libtool-ltdl-devel make openssl-devel pandoc systemd tcp_wrappers-devel openssl11 openssl11-devel python3-devel openssl -y && \
    printf "[ltb-project]\nname=LTB project packages\nbaseurl=https://ltb-project.org/rpm/openldap25/\$releasever/\$basearch\nenabled=1\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-LTB-project" > /etc/yum.repos.d/ltb-project.repo && \
    rpm --import https://ltb-project.org/documentation/_static/RPM-GPG-KEY-LTB-project && \
    yum install libevent-ltb-devel -y && \
    yum install rpm-build rpmdevtools git -y && \
    yum clean all

COPY run/build-packages.sh /opt

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD [ "/bin/bash", "/opt/build-packages.sh"]

