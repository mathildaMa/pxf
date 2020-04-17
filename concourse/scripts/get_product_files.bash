#!/usr/bin/env bash

set -e

: "${PIVNET_API_TOKEN:?PIVNET_API_TOKEN is required}"
: "${PIVNET_CLI_DIR:?PIVNET_CLI_DIR is required}"
: "${VERSION_BEFORE_LATEST:?VERSIONS_BEFORE_LATEST is required}"
: "${GPDB5_RHEL6_RPM_DIR:?GPDB5_RHEL6_RPM_DIR is required}"
: "${GPDB5_RHEL7_RPM_DIR:?GPDB5_RHEL7_RPM_DIR is required}"
: "${GPDB6_RHEL6_RPM_DIR:?GPDB6_RHEL6_RPM_DIR is required}"
: "${GPDB6_RHEL7_RPM_DIR:?GPDB6_RHEL7_RPM_DIR is required}"
: "${GPDB6_UBUNTU18_DEB_DIR:?GPDB6_UBUNTU18_DEB_DIR is required}"
: "${PRODUCT_SLUG:?PRODUCT_SLUG is required}"

pivnet_cli_repo=pivotal-cf/pivnet-cli
PATH=${PIVNET_CLI_DIR}:${PATH}

chmod_pivnet() {
	chmod +x "${PIVNET_CLI_DIR}/pivnet"
}

latest_pivnet_cli_tag=$(curl --silent "https://api.github.com/repos/${pivnet_cli_repo}/releases/latest" | jq -r .tag_name)
if chmod_pivnet && [[ ${latest_pivnet_cli_tag#v} == $(pivnet --version) ]]; then
	echo "Already have version ${latest_pivnet_cli_tag} of pivnet-cli, skipping download..."
else
	echo "Downloading version ${latest_pivnet_cli_tag} of pivnet-cli..."
	wget -q "https://github.com/${pivnet_cli_repo}/releases/download/${latest_pivnet_cli_tag}/pivnet-linux-amd64-${latest_pivnet_cli_tag#v}" -O "${PIVNET_CLI_DIR}/pivnet"
	chmod_pivnet
fi

# log in to pivnet
pivnet login "--api-token=${PIVNET_API_TOKEN}"

# get version numbers in sorted order
# https://stackoverflow.com/questions/57071166/jq-find-the-max-in-quoted-values/57071319#57071319
gpdb6_version=$(
	pivnet --format=json releases "--product-slug=${PRODUCT_SLUG}" | \
		jq --raw-output --argjson m "${VERSION_BEFORE_LATEST}" \
		'sort_by(.version | split(".") | map(tonumber) | select(.[0] == 6))[-1-$m].version'
)
gpdb5_version=$(
	pivnet --format=json releases "--product-slug=${PRODUCT_SLUG}" | \
		jq --raw-output --argjson m "${VERSION_BEFORE_LATEST}" \
		'sort_by(.version | split(".") | map(tonumber) | select(.[0] == 5))[-1-$m].version'
)
echo -e "Latest - ${VERSIONS_BEFORE_LATEST} GPDB versions found:\n6X:\t${gpdb6_version}\n5X:\t${gpdb5_version}"

product_files=(
	"product_files/Pivotal-Greenplum/greenplum-db-${gpdb5_version}-rhel6-x86_64.rpm"
	"product_files/Pivotal-Greenplum/greenplum-db-${gpdb5_version}-rhel7-x86_64.rpm"
	"product_files/Pivotal-Greenplum/greenplum-db-${gpdb6_version}-rhel6-x86_64.rpm"
	"product_files/Pivotal-Greenplum/greenplum-db-${gpdb6_version}-rhel7-x86_64.rpm"
	"product_files/Pivotal-Greenplum/greenplum-db-${gpdb6_version}-ubuntu18.04-amd64.deb"
)
product_dirs=(
	"${GPDB5_RHEL6_RPM_DIR}"
	"${GPDB5_RHEL7_RPM_DIR}"
	"${GPDB6_RHEL6_RPM_DIR}"
	"${GPDB6_RHEL7_RPM_DIR}"
	"${GPDB6_UBUNTU18_DEB_DIR}"
)

gpdb5_product_files_json=$(pivnet --format=json product-files "--product-slug=${PRODUCT_SLUG}" --release-version "${gpdb5_version}")
gpdb6_product_files_json=$(pivnet --format=json product-files "--product-slug=${PRODUCT_SLUG}" --release-version "${gpdb6_version}")
for ((i = 0; i < ${#product_files[@]}; i++)); do
	file=${product_files[$i]}
	download_path=${product_dirs[$i]}/${file##*/}
	version=${gpdb5_version}
	product_files_json=${gpdb5_product_files_json}
	if [[ ${file} =~ ${gpdb6_version} ]]; then
		version=${gpdb6_version}
		product_files_json=${gpdb6_product_files_json}
	fi
	if [[ -e ${download_path} ]]; then
		echo "Found file ${download_path}, checking sha256sum..."
		sha256=$(jq <<<"${product_files_json}" -r --arg object_key "${file}" '.[] | select(.aws_object_key == $object_key).sha256')
		sum=$(sha256sum "${download_path}" | cut -d' ' -f1)
		if [[ ${sum} == "${sha256}" ]]; then
			echo "Sum is equivalent, skipping download of ${file}..."
			continue
		fi
		rm -f "${product_dirs[$i]}"/*.{rpm,deb}
	fi
	id=$(jq <<<"${product_files_json}" -r --arg object_key "${file}" '.[] | select(.aws_object_key == $object_key).id')
	echo "Downloading ${file} with id ${id} to ${product_dirs[$i]}..."
	pivnet download-product-files \
		"--download-dir=${product_dirs[$i]}" \
		"--product-slug=${PRODUCT_SLUG}" \
		"--release-version=${version}" \
		"--product-file-id=${id}" >/dev/null 2>&1 &
	pids+=($!)
done

wait "${pids[@]}"
