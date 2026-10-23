#!/bin/bash

set -e
set -u

# Variables
################################################################################

declare -A DIRS=(["debian"]="10 11 12 13 14" ["centos"]="7" ["rockylinux"]="8 9 10" ["ubuntu"]="22.04 26.04" )

declare -A DEB_DISTS=(["10"]="buster" ["11"]="bullseye" ["12"]="bookworm" ["13"]="trixie" ["14"]="forky" ["22.04"]="jammy" ["26.04"]="resolute")
declare -A RH_DISTS=(["7"]="el7" ["8"]="el8" ["9"]="el9" ["10"]="el10")

VERSIONS=("2.6.16" "2.7.2")

RH_OLD_GPG_NAME="_gpg_name Clement OUDOT (LTB-project) <clem.oudot@gmail.com>"
RH_GPG_NAME="_gpg_name security@ltb-project.org"
DEBIAN_KEYID="0FFE925157BF65E0445DB2F93A769AA11A3F97C4"

PREREQUISITES=("dpkg-sig" "rpm" "rpmsign" "tar" "aptly" "createrepo_c")

# Functions
################################################################################

check_prerequisites() {
    for PREREQUISITE in "${PREREQUISITES[@]}" ; do
        if ! command -v ${PREREQUISITE} >/dev/null 2>&1 ; then
            printf "Error: missing prerequisite: %s\n" "${PREREQUISITE}" >&2
            exit 1;
        fi
    done
    for VERSION in "${VERSIONS[@]}" ; do
        for DIST in "${!DIRS[@]}" ; do
            for VER in ${DIRS[$DIST]} ; do
                if [ "${DIST}" = "debian" ] || [ "${DIST}" = "ubuntu" ]; then
                    MAJORVERSION=$( printf "${VERSION}" | sed -e 's/\([0-9]\+\)\.\([0-9]\+\)\.[0-9]\+/\1.\2/' )
                    DEB_REPO="openldap-ltb-${DEB_DISTS[${VER}]}-${MAJORVERSION}"
                    printf "Checking existence of debian repository %s\n" "${DEB_REPO}"
                    if ! aptly repo show "${DEB_REPO}" >/dev/null 2>&1; then
                        printf "Error: Non-existing debian repository: %s\n" "${DEB_REPO}" >&2
                        printf "Create one with:\n" >&2
                        printf "aptly repo create -comment=\"OpenLDAP LTB ${DEB_DISTS[${VER}]} - ${MAJORVERSION}\" -distribution=\"${DEB_DISTS[${VER}]}\" ${DEB_REPO}\n" >&2
                        exit 1;
                    fi
                fi
            done
        done
    done
}

# Check directory structure
check_input_directories() {
    for VERSION in "${VERSIONS[@]}" ; do
        for DIST in "${!DIRS[@]}" ; do
            for VER in ${DIRS[$DIST]} ; do
                printf "Checking directory: %s\n" "${VERSION}/${DIST}/${VER}";
                if [ ! -d ${VERSION}/${DIST}/${VER} ] ; then
                    printf "Error: missing directory: %s\n" "${VERSION}/${DIST}/${VER}" >&2
                    exit 2;
                fi
            done
        done
    done
}

check_output_directories() {
    for PACKAGE_DIR in ".aptly" "rpm" "archives" ; do
        if [ ! -d "${PACKAGE_DIR}" ] ; then
            printf "Error: missing output directory: %s\n" "${PACKAGE_DIR}" >&2
            exit 3;
        fi
    done
    for VERSION in "${VERSIONS[@]}" ; do
        MAJORVERSION=$( printf "${VERSION}" | sed -e 's/\([0-9]\+\)\.\([0-9]\+\)\.[0-9]\+/\1\2/' )
        for RH_DIST in "${!RH_DISTS[@]}" ; do
            for RPM_DIR in x86_64 SRPMS ; do
                OUTPUT_DIR="rpm/openldap${MAJORVERSION}/${RH_DIST}/${RPM_DIR}"
                if [ ! -d "${OUTPUT_DIR}" ] ; then
                    printf "Error: missing output directory: %s\n" "${OUTPUT_DIR}" >&2
                    exit 3;
                fi
            done
        done
    done
}

sign_packages() {
    # Check packages presence
    printf "INFO: Take care to run this script in a tmux or in a shell able to access to all tty capabilities\n"
    printf "INFO: Especially if you have errors with gpg while trying to unlock the keys with passphrase\n"

    for VERSION in "${VERSIONS[@]}" ; do
        for DIST in "${!DIRS[@]}" ; do
            for VER in ${DIRS[$DIST]} ; do
                if [ "${DIST}" = "debian" ] || [ "${DIST}" = "ubuntu" ]; then
                    for CHANGE in ${VERSION}/${DIST}/${VER}/*.changes ; do
                        if ! grep -q -- '-----BEGIN PGP SIGNATURE-----' ${CHANGE} ; then
                            printf "Package not signed, signing it now: %s\n" "${CHANGE}"
                            # Sign packages with GPG key
                            GPG_TTY=$(tty) dpkg-sig -p --sign builder -k "${DEBIAN_KEYID}" -a full "${CHANGE}"
                        else
                            printf "Package already signed: %s\n" "${RPM}"
                        fi
                    done
                fi
                if [ "${DIST}" = "centos" ] || [ "${DIST}" = "rockylinux" ]; then
                    for RPM in ${VERSION}/${DIST}/${VER}/*.rpm ; do
                        if ! rpm -qpi ${RPM} 2>/dev/null | grep -q -E '^Signature.*Key ID' ; then
                            printf "Package not signed, signing it now: %s\n" "${RPM}"
                            if [ "${VER}" = "7" ]; then
                                # Sign packages with old GPG key
                                GPG_TTY=$(tty) rpmsign --define "${RH_OLD_GPG_NAME}" --addsign "${RPM}"
                            else
                                # Sign packages with new GPG key
                                GPG_TTY=$(tty) rpmsign --define "${RH_GPG_NAME}" --addsign "${RPM}"
                            fi
                        else
                            printf "Package already signed: %s\n" "${RPM}"
                        fi
                    done
                fi
            done
        done
    done
}

## Push packages to their correct location
## * push rpm (rpm/openldap25/9/x86_64/)
## * push src rpms (rpm/openldap25/9/SRPMS/)
## * push deb (aptly repo add)
push_packages_to_repositories() {
    for VERSION in "${VERSIONS[@]}" ; do
        for DIST in "${!DIRS[@]}" ; do
            for VER in ${DIRS[$DIST]} ; do
                if [ "${DIST}" = "debian" ] || [ "${DIST}" = "ubuntu" ]; then
                    MAJORVERSION=$( printf "${VERSION}" | sed -e 's/\([0-9]\+\)\.\([0-9]\+\)\.[0-9]\+/\1.\2/' )
                    DEB_REPO="openldap-ltb-${DEB_DISTS[${VER}]}-${MAJORVERSION}"
                    # Check and remove existing package in repo
                    if aptly repo search "${DEB_REPO}" "Version (=${VERSION}.1)" ; then
                        printf "Remove previous packages from debian repository %s\n" "${DEB_REPO}"
                        aptly repo remove "${DEB_REPO}" "Version (=${VERSION}.1)"
                    fi
                    printf "Add packages from %s to debian repository %s\n" "${VERSION}/${DIST}/${VER}/*.deb" "${DEB_REPO}"
                    aptly repo add "${DEB_REPO}" ${VERSION}/${DIST}/${VER}/*.deb
                fi
                if [ "${DIST}" = "centos" ] || [ "${DIST}" = "rockylinux" ]; then
                    MAJORVERSION=$( printf "${VERSION}" | sed -e 's/\([0-9]\+\)\.\([0-9]\+\)\.[0-9]\+/\1\2/' )
                    printf "Add packages from %s to rpm repository %s\n" "${VERSION}/${DIST}/${VER}/*.rpm" "rpm/openldap${MAJORVERSION}/${VER}"
                    for RPM in ${VERSION}/${DIST}/${VER}/*[^.src].rpm ; do
                        cp -f ${RPM} "rpm/openldap${MAJORVERSION}/${VER}/x86_64/"
                    done
                    for SRPM in ${VERSION}/${DIST}/${VER}/*.src.rpm ; do
                        cp -f ${SRPM} "rpm/openldap${MAJORVERSION}/${VER}/SRPMS/"
                    done
                fi
            done
        done
    done
}

update_repositories() {
    for VERSION in "${VERSIONS[@]}" ; do
        for DIST in "${!DIRS[@]}" ; do
            for VER in ${DIRS[$DIST]} ; do
                if [ "${DIST}" = "debian" ] || [ "${DIST}" = "ubuntu" ]; then
                    MAJORVERSION=$( printf "${VERSION}" | sed -e 's/\([0-9]\+\)\.\([0-9]\+\)\.[0-9]\+/\1.\2/' )
                    DEB_REPO="openldap-ltb-${DEB_DISTS[${VER}]}-${MAJORVERSION}"
                    printf "Update debian repository %s\n" "${DEB_REPO}"
                    #TODO: avoid packages pushed multiple times on the repository (resulting in multiple inodes for the same file in .aptly/pool)
                    # Check with:
                    # find .aptly/ -name '*openldap-ltb_2.5.19.1_amd64.deb*' | xargs -I {} ls -i {} | sed -e 's/ .*$//' | xargs -I {} sh -c 'echo inode: {} && find .aptly/ -inum {}'
                    # You can use -force-overwrite if you are sure there is no conflict!
                    aptly publish update -force-overwrite -gpg-key="${DEBIAN_KEYID}" -architectures="amd64" ${DEB_DISTS[${VER}]} ${DEB_REPO}
                fi
                if [ "${DIST}" = "centos" ] || [ "${DIST}" = "rockylinux" ]; then
                    MAJORVERSION=$( printf "${VERSION}" | sed -e 's/\([0-9]\+\)\.\([0-9]\+\)\.[0-9]\+/\1\2/' )
                    printf "Update rpm repository %s\n" "rpm/openldap${MAJORVERSION}/${VER}/x86_64/"
                    createrepo_c "rpm/openldap${MAJORVERSION}/${VER}/x86_64/"
                    createrepo_c "rpm/openldap${MAJORVERSION}/${VER}/SRPMS/"
                fi
            done
        done
    done
}

create_archives() {
    for VERSION in "${VERSIONS[@]}" ; do
        for DIST in "${!DIRS[@]}" ; do
            for VER in ${DIRS[$DIST]} ; do
                if [ "${DIST}" = "debian" ] || [ "${DIST}" = "ubuntu" ]; then
                    printf "Create archive: %s\n" "${VERSION}/${DIST}/${VER}/openldap-ltb-${VERSION}-${DEB_DISTS[${VER}]}-64.tar.gz"
                    cd "${VERSION}/${DIST}/${VER}"
                    tar czf "openldap-ltb-${VERSION}-${DEB_DISTS[${VER}]}-64.tar.gz" *.deb
                    cd ../../..
                fi
                if [ "${DIST}" = "centos" ] || [ "${DIST}" = "rockylinux" ]; then
                    printf "Create archive: %s\n" "${VERSION}/${DIST}/${VER}/openldap-ltb-${VERSION}-${RH_DISTS[${VER}]}-64.tar.gz"
                    cd "${VERSION}/${DIST}/${VER}"
                    tar czf "openldap-ltb-${VERSION}-${RH_DISTS[${VER}]}-64.tar.gz" openldap-ltb-*[^.src].rpm
                    cd ../../..
                fi
            done
        done
    done
}

push_archives() {
    for VERSION in "${VERSIONS[@]}" ; do
        for DIST in "${!DIRS[@]}" ; do
            for VER in ${DIRS[$DIST]} ; do
                if [ "${DIST}" = "debian" ] || [ "${DIST}" = "ubuntu" ]; then
                    printf "Push %s to archives/ directory\n" "${VERSION}/${DIST}/${VER}/openldap-ltb-${VERSION}-${DEB_DISTS[${VER}]}-64.tar.gz"
                    cp -f "${VERSION}/${DIST}/${VER}/openldap-ltb-${VERSION}-${DEB_DISTS[${VER}]}-64.tar.gz" archives/
                fi
                if [ "${DIST}" = "centos" ] || [ "${DIST}" = "rockylinux" ]; then
                    printf "Push %s to archives/ directory\n" "${VERSION}/${DIST}/${VER}/openldap-ltb-${VERSION}-${RH_DISTS[${VER}]}-64.tar.gz"
                    cp -f "${VERSION}/${DIST}/${VER}/openldap-ltb-${VERSION}-${RH_DISTS[${VER}]}-64.tar.gz" archives/
                fi
            done
        done
    done
}


# Entry point
################################################################################

## Check availability of prerequisites
## all commands: rpm, aptly, createrepo,...
check_prerequisites

## Check the input directory structure (for instance: 2.5.19/debian/12)
check_input_directories

## Check the destination directories where to push the packages
check_output_directories

## Verify package signature and sign them if necessary
sign_packages

## Push packages to their correct repository location
push_packages_to_repositories

## Update deb and rpm repositories
update_repositories

## Create archive packages
create_archives

## Push archives to their correct location
push_archives
