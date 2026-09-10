#!/bin/bash

set -e
set -u

SLAPD_CLI_VERSION=${SLAPD_CLI_VERSION:-"3.7"}
PPM_VERSION=${PPM_VERSION:-"2.2"}
EXPLOCKOUT_VERSION=${EXPLOCKOUT_VERSION:-"1.2"}


OPENLDAP_URL="https://gpl.savoirfairelinux.net/pub/mirrors/openldap/openldap-release/openldap-${OPENLDAP_VERSION}.tgz"
declare -A SOURCES=( ["slapd-cli"]="https://github.com/ltb-project/slapd-cli/archive/refs/tags/v${SLAPD_CLI_VERSION}.tar.gz" \
                     ["ppm"]="https://github.com/ltb-project/ppm/archive/refs/tags/v${PPM_VERSION}.tar.gz" \
                     ["explockout"]="https://github.com/ltb-project/explockout/archive/refs/tags/v${EXPLOCKOUT_VERSION}.tar.gz" \
                   )


LTB_DEB_REPOSITORY_URL="https://github.com/ltb-project/openldap-deb.git"
LTB_RPM_REPOSITORY_URL="https://github.com/ltb-project/openldap-rpm.git"

DEBEMAIL="david.coutadeur@gmail.com"
DEBFULLNAME="David Coutadeur"
export DEBEMAIL DEBFULLNAME

PACKAGES_VOLUME="/packages"

if [ -z ${OPENLDAP_VERSION} ]; then
    echo "Missing OPENLDAP_VERSION"
    exit 1
fi
if [ -z ${LTB_REPOSITORY_REFERENCE} ]; then
    echo "Missing LTB_REPOSITORY_REFERENCE"
    exit 1
fi


# Get sources

BUILD_PATH=/opt
cd ${BUILD_PATH}


if [ -f /etc/redhat-release ]; then

    cat <<EOF >> ~/.rpmmacros
%_topdir ${BUILD_PATH}/openldap-rpm
%packager ${DEBFULLNAME} <${DEBEMAIL}>
EOF

    echo "Red-hat base distribution detected"
    echo "Get LTB RPM repository"
    git clone "${LTB_RPM_REPOSITORY_URL}"
    cd ${BUILD_PATH}/openldap-rpm
    git checkout "${LTB_REPOSITORY_REFERENCE}"

    echo "Get OpenLDAP source ${OPENLDAP_URL}"
    cd ${BUILD_PATH}/openldap-rpm/SOURCES
    curl -s -L -O ${OPENLDAP_URL}

    for source in ${!SOURCES[@]}; do
        URL=${SOURCES[${source}]}
        echo "Get source ${URL}"
        curl -s -L -O ${URL}
        FILE=${URL##*/}
        mv ${FILE} ${source}-${FILE#v}
    done

    cd ${BUILD_PATH}/openldap-rpm

    rpmbuild -ba SPECS/openldap-ltb.spec

    cp -f ${BUILD_PATH}/openldap-rpm/RPMS/x86_64/* \
          ${BUILD_PATH}/openldap-rpm/SRPMS/* \
          ${PACKAGES_VOLUME}/

    
elif [ -f /etc/debian_version ]; then
    echo "Debian base distribution detected"
    echo "Get LTB DEB repository"
    git clone "${LTB_DEB_REPOSITORY_URL}"
    cd ${BUILD_PATH}/openldap-deb
    git checkout "${LTB_REPOSITORY_REFERENCE}"

    echo "Get OpenLDAP source ${OPENLDAP_URL}"
    curl -s -L -O ${OPENLDAP_URL}
    echo "Extract ${OPENLDAP_URL##*/}"
    tar xzf ${OPENLDAP_URL##*/}
    rm ${OPENLDAP_URL##*/}
    cp -r openldap-2*/* openldap-ltb/

    cd ${BUILD_PATH}/openldap-deb/3rdparty
    for source in ${!SOURCES[@]}; do
        URL=${SOURCES[${source}]}
        echo "Get source ${URL}"
        curl -s -L -O "${URL}"
        FILE=${URL##*/}
        echo "Extract ${FILE}"
        tar xzf ${FILE}
        rm ${FILE}
    done
    cd ${BUILD_PATH}/openldap-deb/openldap-ltb

    dpkg-buildpackage -us -uc

    cp -f ${BUILD_PATH}/openldap-deb/*.deb \
          ${BUILD_PATH}/openldap-deb/*.buildinfo \
          ${BUILD_PATH}/openldap-deb/*.changes \
          ${BUILD_PATH}/openldap-deb/*.dsc \
          ${BUILD_PATH}/openldap-deb/*.tar.xz \
          ${PACKAGES_VOLUME}/

else
    echo "Unknown linux distribution"
    exit 1
fi


