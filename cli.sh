#!/bin/bash

set -e

################################################################################
# Variables
################################################################################

CTN="docker"
PWD=$( pwd )

# associative array :
# docker image name to build => directory to Dockerfile
declare -A DISTRIBUTIONS=( ["centos-7-ltb"]="images/centos-7" \
                           ["centos-8-ltb"]="images/centos-8" \
                           ["debian-10-ltb"]="images/debian-10" \
                           ["debian-11-ltb"]="images/debian-11" \
                           ["debian-12-ltb"]="images/debian-12" \
                           ["debian-13-ltb"]="images/debian-13" \
                           ["debian-14-ltb"]="images/debian-14" \
                           ["rockylinux-8-ltb"]="images/rockylinux-8" \
                           ["rockylinux-9-ltb"]="images/rockylinux-9" \
                           ["rockylinux-10-ltb"]="images/rockylinux-10" \
                           ["ubuntu-22.04-ltb"]="images/ubuntu-22.04" \
                           ["ubuntu-26.04-ltb"]="images/ubuntu-26.04" \
                         )
IMAGE_VERSION="0.1"

# associative array :
# OpenLDAP version => reference to git branch, commit, or tag on LTB repository
declare -A OPENLDAP_VERSIONS=( ["2.6.15"]="openldap26" \
                               ["2.7.1"]="openldap27" \
                             )



################################################################################
# Functions
################################################################################


print_sorted_values() {
    local sorted=()
    while IFS= read -rd '' key; do
        sorted+=( "$key" )
    done < <(printf '%s\0' "$@" | sort -z)
    for key in "${!sorted[@]}"; do printf "%s " "${sorted[${key}]}" ; done
    echo
}

select_images() {
    if [ -z "${1}" ]; then
        DISTS=$( print_sorted_values ${!DISTRIBUTIONS[@]} )
    else
        DISTS=$( print_sorted_values ${@} )
    fi
}

select_versions() {
    if [ -z "${1}" ]; then
        VERSIONS=$( print_sorted_values ${!OPENLDAP_VERSIONS[@]} )
    else
        VERSIONS=$( print_sorted_values ${@} )
    fi
}

build_images () {

    for DISTRIBUTION in ${DISTS}; do
        echo "Build ${DISTRIBUTION} distribution in ${DISTRIBUTIONS[${DISTRIBUTION}]}"
        ${CTN} build --no-cache -t ${DISTRIBUTION}:${IMAGE_VERSION} -f ${DISTRIBUTIONS[${DISTRIBUTION}]}/Dockerfile .
    done
}

build_packages () {

    for DISTRIBUTION in ${DISTS}; do
        for OPENLDAP_VERSION in ${VERSIONS}; do
            echo "Build packages OpenLDAP-LTB ${OPENLDAP_VERSION} for ${DISTRIBUTION} distribution"
            mkdir -p run/volumes/${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}
            ${CTN} run \
                    -v ${PWD}/run/volumes/${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}:/packages \
                    --env OPENLDAP_VERSION=${OPENLDAP_VERSION} \
                    --env LTB_REPOSITORY_REFERENCE=${OPENLDAP_VERSIONS[${OPENLDAP_VERSION}]} \
                    --name=${DISTRIBUTION}-openldap-${OPENLDAP_VERSION} \
                    --detach=true \
                    ${DISTRIBUTION}:${IMAGE_VERSION}
        done
    done
}

remove_images () {

    for DISTRIBUTION in ${DISTS}; do

            if ${CTN} image inspect "${DISTRIBUTION}:${IMAGE_VERSION}" > /dev/null 2>&1; then
                # Image exists
                echo "Remove image ${DISTRIBUTION}:${IMAGE_VERSION}"
                ${CTN} image rm "${DISTRIBUTION}:${IMAGE_VERSION}"

            else

                echo "No docker image ${DISTRIBUTION}:${IMAGE_VERSION}, nothing to do"

            fi

    done

    # Remove unused images
    ${CTN} image prune -f
    # Remove intermediate cache
    ${CTN} builder prune -f
}

remove_containers () {

    for DISTRIBUTION in ${DISTS}; do
        for OPENLDAP_VERSION in ${VERSIONS}; do

            if ${CTN} inspect "${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}" > /dev/null 2>&1; then
                # Container exists
                if $(${CTN} inspect -f '{{.State.Status}}' "${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}" | grep -q "running"); then
                    # Container is running
                    echo "Stop container ${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}"
                    ${CTN} stop "${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}"
                fi
                echo "Remove container ${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}"
                ${CTN} rm "${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}"

            else

                echo "No container ${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}, nothing to do"

            fi

        done
    done
}

run_containers () {

    for DISTRIBUTION in ${DISTS}; do
        for OPENLDAP_VERSION in ${VERSIONS}; do
            echo "Run container ${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}"
            mkdir -p run/volumes/${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}
            ${CTN} run \
                    -it \
                    -v ${PWD}/run/volumes/${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}:/packages \
                    --env OPENLDAP_VERSION=${OPENLDAP_VERSION} \
                    --env LTB_REPOSITORY_REFERENCE=${OPENLDAP_VERSIONS[${OPENLDAP_VERSION}]} \
                    --name=${DISTRIBUTION}-openldap-${OPENLDAP_VERSION} \
                    --detach=true \
                    --entrypoint=/bin/bash \
                    ${DISTRIBUTION}:${IMAGE_VERSION}

            echo "Enter the container with the command:"
            echo "${CTN} exec -it ${DISTRIBUTION}-openldap-${OPENLDAP_VERSION} /bin/bash"
            echo "and build with:"
            echo "/opt/build-packages.sh"
            echo
        done
    done
}

fetch_packages () {
    echo "Fetch OpenLDAP packages, make sure you have read permissions to run/volumes/*"
    rm -rf packages
    for DISTRIBUTION in ${DISTS}; do
        for OPENLDAP_VERSION in ${VERSIONS}; do
            OS_NAME=${DISTRIBUTION%%-*}
            OS_VERSION=${DISTRIBUTION#${OS_NAME}-}
            OS_VERSION=${OS_VERSION%%-*}
            echo "Fetch ${OPENLDAP_VERSION} OpenLDAP packages for distribution ${OS_NAME}/${OS_VERSION}"
            mkdir -p "packages/${OPENLDAP_VERSION}/${OS_NAME}/${OS_VERSION}"
            cp -f run/volumes/${DISTRIBUTION}-openldap-${OPENLDAP_VERSION}/* "packages/${OPENLDAP_VERSION}/${OS_NAME}/${OS_VERSION}/"
        done
    done
    cd packages/
    tar czf packages.tar.gz ${VERSIONS}
    cd ..
}



################################################################################
# Entrypoint
################################################################################


POSITIONAL_ARGS=()

# Check options

while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--image)
      IFS=',' read -ra SELECTED_IMAGES <<< "${2}"
      shift # past argument
      shift # past value
      ;;
    -v|--version)
      IFS=',' read -ra SELECTED_VERSIONS <<< "${2}"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

select_images ${SELECTED_IMAGES[@]}
select_versions ${SELECTED_VERSIONS[@]}

# Check positional args
case ${POSITIONAL_ARGS[0]} in

    build-images | build-image)
      echo "Selected images: ${DISTS}"
      build_images
      exit 0
      ;;

    build-packages | build-package)
      echo "Selected images: ${DISTS}"
      echo "Selected versions: ${VERSIONS}"
      build_packages
      exit 0
      ;;

    remove-images | remove-image)
      echo "Selected images: ${DISTS}"
      remove_images
      exit 0
      ;;

    remove-containers | remove-container)
      echo "Selected images: ${DISTS}"
      echo "Selected versions: ${VERSIONS}"
      remove_containers
      exit 0
      ;;

    run-containers | run-container)
      echo "Selected images: ${DISTS}"
      echo "Selected versions: ${VERSIONS}"
      run_containers
      exit 0
      ;;

    fetch-packages | fetch-package)
      echo "Selected images: ${DISTS}"
      echo "Selected versions: ${VERSIONS}"
      fetch_packages
      exit 0
      ;;

  *)
    echo "$0 [-i|--image image1,image2] [-v|--version version1,version2] [build-images|build-packages|remove-images|remove-containers|run-containers|fetch-packages]"
    echo
    echo "OPTIONS"
    echo "  -i: optional, name of the docker image to consider. If empty, use all images in DISTRIBUTIONS"
    echo "  -v: optional, version of OpenLDAP to consider. If empty, use all images in OPENLDAP_VERSIONS"
    echo
    echo "ACTIONS"
    echo "  build-images: build images containing build dependencies"
    echo "  build-packages: run containers that builds OpenLDAP-LTB packages. One container would be launched for each OPENLDAP_VERSIONS and DISTRIBUTIONS"
    echo "  remove-images: remove images"
    echo "  remove-containers: remove container for every OPENLDAP_VERSIONS of given images"
    echo "  run-containers: run container for every OPENLDAP_VERSIONS of given images without building the package"
    echo "  fetch-packages: fetch packages built previously, for given DISTRIBUTIONS and OPENLDAP_VERSIONS"
    echo
    echo "Declared DISTRIBUTIONS images:"
    echo $( print_sorted_values ${!DISTRIBUTIONS[@]} )
    echo
    echo "Declared OPENLDAP_VERSIONS:"
    echo $( print_sorted_values ${!OPENLDAP_VERSIONS[@]} )
    echo
    echo "Selected images: ${DISTS}"
    echo "Selected versions: ${VERSIONS}"
    exit 0
    ;;

esac
