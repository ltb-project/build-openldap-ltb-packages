#!/bin/bash

set -e
set -u

PACKAGES_VOLUME="/packages"
OPENLDAP_PATH="/usr/local/openldap"
SLAPD_CLI_PATH="${OPENLDAP_PATH}/sbin/slapd-cli"
LDAPSEARCH_PATH="${OPENLDAP_PATH}/bin/ldapsearch"
SUFFIX="dc=my-domain,dc=com"
MANAGER_DN="cn=Manager,${SUFFIX}"
MANAGER_PW="secret"

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

    echo "Red-hat base distribution detected"
    echo "Install OpenLDAP packages"

    rpm -Uvh ${PACKAGES_VOLUME}/*.rpm

elif [ -f /etc/debian_version ]; then
    echo "Debian base distribution detected"
    echo "Install OpenLDAP packages"

    dpkg -i ${PACKAGES_VOLUME}/*.deb

else
    echo "Unknown linux distribution"
    exit 1
fi

# Import sample configuration
${SLAPD_CLI_PATH} importldifconfigtemplate

# Import sample data
${SLAPD_CLI_PATH} importdatatemplate

# Start LDAP
${SLAPD_CLI_PATH} start

# Test a LDAP search
${LDAPSEARCH_PATH} -x -H 'ldap://127.0.0.1:389' -D "${MANAGER_DN}" -w "${MANAGER_PW}" -b "${SUFFIX}" -s base -LLL


