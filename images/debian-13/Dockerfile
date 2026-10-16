FROM debian:trixie

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

# Install dependencies for Debian
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install autoconf automake autotools-dev debhelper dh-make devscripts fakeroot file gnupg git lintian patch patchutils pbuilder curl && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install libltdl7 libltdl-dev libsasl2-2 libsasl2-dev zlib1g zlib1g-dev openssl libssl-dev mawk libcrack2-dev libwrap0-dev libevent-dev libsodium23 libsodium-dev pandoc procps bash-completion && \
    apt clean all

COPY run/build-packages.sh /opt
COPY run/test-packages.sh /opt

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD [ "/bin/bash", "/opt/build-packages.sh"]

