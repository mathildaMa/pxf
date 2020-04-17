#!/usr/bin/env bash

set -eox pipefail

: "${TARGET_OS:?TARGET_OS must be set}"
: "${TARGET_AR:?TARGET_AR must be set}"

GPDB_PKG_DIR=gpdb_package
GPDB_VERSION=$(<"${GPDB_PKG_DIR}/version")
GPDB_MAJOR_VERSION=${GPDB_VERSION:0:1}
GPHOME=/usr/local/greenplum-db-${GPDB_VERSION}
PPE_VERSION=1.0.0

function install_gpdb() {
    if [[ ${TARGET_OS} == rhel* ]]; then
	    rpm --quiet -ivh "${GPDB_PKG_DIR}/greenplum-db-${GPDB_VERSION}"-rhel*-x86_64.rpm
    elif [[ ${TARGET_OS} == ubuntu* ]]; then
	    # apt wants a full path
	    apt install -qq "${PWD}/${GPDB_PKG_DIR}/greenplum-db-${GPDB_VERSION}-ubuntu18.04-amd64.deb"
    else
	    echo "Unsupported operating system ${TARGET_OS}. Exiting..."
	    exit 1
    fi
}

function compile_pxf_protocol_extension() {
    source "${GPHOME}/greenplum_path.sh"
    if [[ ${TARGET_OS} == "rhel6" ]]; then
	    source /opt/gcc_env.sh
    fi

    USE_PGXS=1 make -C "pxf-protocol-extension_src"
}

function package_pxf_protocol_extension() {

    # store latest commit SHA
    pushd pxf-protocol-extension_src > /dev/null
    echo $(git rev-parse --verify HEAD) > commit.sha
    echo ${PPE_VERSION} > version
    popd > /dev/null

    # establish OS-specific package name
    local package_name=ppe-gpdb${GPDB_MAJOR_VERSION}-${PPE_VERSION}-${TARGET_OS}-${TARGET_AR}

    # prepare directory layout for artifacts
    mkdir -p dist/${package_name}/{lib/postgresql,share/postgresql/extension}

    # place artifacts into appropriate locations
    cp pxf-protocol-extension_src/pxf.so dist/${package_name}/lib/postgresql/
    cp pxf-protocol-extension_src/pxf*.{sql,control} dist/${package_name}/share/postgresql/extension/
    cp pxf-protocol-extension_src/{commit.sha,version,concourse/scripts/install_component.bash} dist/${package_name}

    # package artifacts into a tarball
    pushd dist > /dev/null
    tar cvzf ${package_name}.tar.gz ${package_name}
    popd > /dev/null

    # verify contents
    ls -al dist
    tar -tvzf dist/${package_name}.tar.gz
}

install_gpdb
compile_pxf_protocol_extension
package_pxf_protocol_extension