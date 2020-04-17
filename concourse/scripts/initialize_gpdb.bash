#!/usr/bin/env bash

set -exuo pipefail

GPHOME=/usr/local/greenplum-db
PYTHONHOME='' source "${GPHOME}/greenplum_path.sh"

# Create config and data dirs.
data_dirs=(~gpadmin/data{1..6}/primary)
dirs=(~gpadmin/{gpconfigs,data/master} "${data_dirs[@]}")
mkdir -p "${dirs[@]}"

sed -e "s/MASTER_HOSTNAME=mdw/MASTER_HOSTNAME=\$(hostname -f)/g" \
	-e "s|declare -a DATA_DIRECTORY.*|declare -a DATA_DIRECTORY=( ${data_dirs[*]} )|g" \
	-e "s|MASTER_DIRECTORY=.*|MASTER_DIRECTORY=~gpadmin/data/master|g" \
	"${GPHOME}/docs/cli_help/gpconfigs/gpinitsystem_config" >~gpadmin/gpconfigs/gpinitsystem_config
chmod +w ~gpadmin/gpconfigs/gpinitsystem_config

#Script to start segments and create directories.
hostname -f >/tmp/hosts.txt

# gpinitsystem fails in concourse environment without this "ping" workaround. "[FATAL]:-Unknown host..."
sudo chmod u+s /bin/ping

pgrep sshd || sudo /usr/sbin/sshd
gpssh-exkeys -f /tmp/hosts.txt

gpinitsystem --ignore-warnings -a -c ~gpadmin/gpconfigs/gpinitsystem_config -h /tmp/hosts.txt --su_password=changeme

echo 'host all all 0.0.0.0/0 password' >>~gpadmin/data/master/gpseg-1/pg_hba.conf

# reload pg_hba.conf
MASTER_DATA_DIRECTORY=~gpadmin/data/master/gpseg-1 gpstop -u

psql -d template1 -c "CREATE DATABASE gpadmin;"
