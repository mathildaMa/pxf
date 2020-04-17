#!/usr/bin/env bash

set -e

: "${GPDB_PKG_DIR:?GPDB_PKG_DIR must be set}"
: "${PXF_PROTOCOL_EXTENSION_SRC:?PXF_PROTOCOL_EXTENSION_SRC must be set}"

BASE_DIR=${PWD}

version=$(<"${GPDB_PKG_DIR}/version")
if command -v rpm; then
	rpm --quiet -ivh "${GPDB_PKG_DIR}/greenplum-db-${version}"-rhel*-x86_64.rpm
elif command -v apt; then
	# apt wants a full path
	apt install -qq "${PWD}/${GPDB_PKG_DIR}/greenplum-db-${version}-ubuntu18.04-amd64.deb"
else
	echo "Cannot install RPM or DEB from ${GPDB_PKG_DIR}, no rpm or apt command available in this environment. Exiting..."
	exit 1
fi

gphome=/usr/local/greenplum-db-${version}
list_of_pxf_files=(
	"${gphome}/share/postgresql/extension/pxf.control"
	"${gphome}/share/postgresql/extension/pxf--1.0.sql"
	"${gphome}/pxf"
	"${gphome}/lib/postgresql/pxf.so"
)

for file in "${list_of_pxf_files[@]}"; do
	if ! [[ -e "${file}" ]]; then
		echo "${file} not found in GPDB archive, skipping..."
		continue
	fi
	echo "removing ${file} from GPDB archive"
	rm -rf "${file}"
done

source "${gphome}/greenplum_path.sh"
if grep 'CentOS release 6' /etc/centos-release >/dev/null; then
	source /opt/gcc_env.sh
fi
USE_PGXS=1 make -C "${PXF_PROTOCOL_EXTENSION_SRC}" install

# create symlink to allow pgregress to run (hardcoded to look for /usr/local/greenplum-db-devel/psql)
rm -rf /usr/local/greenplum-db-devel
ln -sf "/usr/local/greenplum-db-${version}" /usr/local/greenplum-db-devel
