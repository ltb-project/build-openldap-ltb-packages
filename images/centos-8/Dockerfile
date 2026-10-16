FROM centos:8

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

# Install dependencies for CentOS 8
# CentOS Linux 8 had reached the End Of Life (EOL) on December 31st, 2021.
# It means that CentOS 8 will no longer receive development resources from the official CentOS project.
# After Dec 31st, 2021, if you need to update your CentOS, you need to change the mirrors to vault.centos.org where they will be archived permanently.
# Alternatively, you may want to upgrade to CentOS Stream.
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* && \
    yum update -y && \
    yum install 'dnf-command(config-manager)' -y && \
    yum config-manager --set-enabled powertools -y && \
    yum install epel-release -y && \
    yum install cracklib-devel cyrus-sasl-devel gcc groff krb5-devel libevent-devel libsodium-devel libtool-ltdl-devel make openssl-devel pandoc systemd -y && \
    yum install rpm-build rpmdevtools git -y && \
    yum install bash-completion -y && \
    yum clean all

COPY run/build-packages.sh /opt
COPY run/test-packages.sh /opt

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD [ "/bin/bash", "/opt/build-packages.sh"]

