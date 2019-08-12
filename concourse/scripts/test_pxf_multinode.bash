#!/bin/bash -l

set -exo pipefail

CWDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${CWDIR}/pxf_common.bash"

SSH_OPTS=(-i cluster_env_files/private_key.pem -o 'StrictHostKeyChecking=no')
GPHD_ROOT="/singlecluster"

function configure_local_hdfs() {

	sed -i -e "s|hdfs://0.0.0.0:8020|hdfs://${HADOOP_HOSTNAME}:8020|" \
	${GPHD_ROOT}/hadoop/etc/hadoop/core-site.xml ${GPHD_ROOT}/hbase/conf/hbase-site.xml
}

function run_multinode_smoke_test() {

	echo "Running multinode smoke test with ${NO_OF_FILES} files"
	time ssh hadoop "export JAVA_HOME=/etc/alternatives/jre_1.8.0_openjdk
	${GPHD_ROOT}/bin/hdfs dfs -mkdir -p /tmp && mkdir -p /tmp/pxf_test && \
	for i in \$(seq 1 ${NO_OF_FILES}); do \
	cat > /tmp/pxf_test/test_\${i}.txt <<-EOF
	1
	2
	3
	EOF
	done && \
	${GPHD_ROOT}/bin/hdfs dfs -copyFromLocal /tmp/pxf_test/ /tmp && \
	${GPHD_ROOT}/bin/hdfs dfs -chown -R gpadmin:gpadmin /tmp/pxf_test"

	echo "Found $(${GPHD_ROOT}/bin/hdfs dfs -ls /tmp/pxf_test | grep pxf_test | wc -l) items in /tmp/pxf_test"
	expected_output=$((3 * NO_OF_FILES))

	time ssh "${SSH_OPTS[@]}" gpadmin@mdw "source ${GPHOME}/greenplum_path.sh
	psql -d template1 -c \"
	CREATE EXTERNAL TABLE pxf_multifile_test (b TEXT) LOCATION ('pxf://tmp/pxf_test?PROFILE=HdfsTextSimple') FORMAT 'CSV';\"
	num_rows=\$(psql -d template1 -t -c \"SELECT COUNT(*) FROM pxf_multifile_test;\" | head -1)
	if [[ \${num_rows} == ${expected_output} ]] ; then
		echo \"Received expected output\"
	else
		echo \"Error. Expected output ${expected_output} does not match actual \${num_rows}\"
		exit 1
	fi"
}

function open_ssh_tunnels() {

	# https://stackoverflow.com/questions/2241063/bash-script-to-setup-a-temporary-ssh-tunnel
	ssh -fNT -M -S /tmp/mdw5432 -L 5432:mdw:5432 gpadmin@mdw
	ssh -S /tmp/mdw5432 -O check gpadmin@mdw

	if [[ ! -d dataproc_env_files ]]; then
		ssh-keyscan "$HADOOP_HOSTNAME" >> /root/.ssh/known_hosts
		ssh -fNT -M -S /tmp/hadoop2181 -L 2181:hadoop:2181 root@hadoop
		ssh -S /tmp/hadoop2181 -O check root@hadoop
	fi
}

function close_ssh_tunnels() {
	ssh -S /tmp/mdw5432 -O exit gpadmin@mdw
	if [[ ! -d dataproc_env_files ]]; then
		ssh -S /tmp/hadoop2181 -O exit root@hadoop
 	fi
}

function update_pghba_conf() {
    local sdw_ips=("$@")
    for ip in "${sdw_ips[@]}"; do
        echo "host     all         gpadmin         $ip/32    trust" >> pg_hba.patch
    done
    scp "${SSH_OPTS[@]}" pg_hba.patch gpadmin@mdw:

    ssh "${SSH_OPTS[@]}" gpadmin@mdw "
        cat pg_hba.patch >> /data/gpdata/master/gpseg-1/pg_hba.conf &&
        cat /data/gpdata/master/gpseg-1/pg_hba.conf"
}

function setup_pxf_on_cluster() {
    # drop named query file for JDBC test to gpadmin's home on mdw
    scp "${SSH_OPTS[@]}" pxf_src/automation/src/test/resources/report.sql gpadmin@mdw:
    scp "${SSH_OPTS[@]}" pxf_src/automation/src/test/resources/hive-report.sql gpadmin@mdw:

    # PXF is already un-tarred on the segments (concource/scripts/install_pxf.bash)

    # init all PXFs using cluster command, configure PXF on master, sync configs and start pxf
    ssh "${SSH_OPTS[@]}" gpadmin@mdw "source ${GPHOME}/greenplum_path.sh &&
        if [[ ! -d ${PXF_CONF_DIR} ]]; then
          PXF_CONF=${PXF_CONF_DIR} ${GPHOME}/pxf/bin/pxf cluster init
          cp ${PXF_CONF_DIR}/templates/{hdfs,mapred,yarn,core,hbase,hive}-site.xml ${PXF_CONF_DIR}/servers/default/
          sed -i -e 's/\(0.0.0.0\|localhost\|127.0.0.1\)/${hadoop_ip}/g' ${PXF_CONF_DIR}/servers/default/*-site.xml
        else
          cp ${PXF_CONF_DIR}/templates/mapred-site.xml ${PXF_CONF_DIR}/servers/default/mapred1-site.xml
        fi &&
        mkdir -p ${PXF_CONF_DIR}/servers/s3 && mkdir -p ${PXF_CONF_DIR}/servers/s3-invalid &&
        cp ${PXF_CONF_DIR}/templates/s3-site.xml ${PXF_CONF_DIR}/servers/s3/ &&
        cp ${PXF_CONF_DIR}/templates/s3-site.xml ${PXF_CONF_DIR}/servers/s3-invalid/ &&
        sed -i \"s|YOUR_AWS_ACCESS_KEY_ID|${ACCESS_KEY_ID}|\" ${PXF_CONF_DIR}/servers/s3/s3-site.xml &&
        sed -i \"s|YOUR_AWS_SECRET_ACCESS_KEY|${SECRET_ACCESS_KEY}|\" ${PXF_CONF_DIR}/servers/s3/s3-site.xml &&
        mkdir -p ${PXF_CONF_DIR}/servers/database &&
        cp ${PXF_CONF_DIR}/templates/jdbc-site.xml ${PXF_CONF_DIR}/servers/database/ &&
        sed -i \"s|YOUR_DATABASE_JDBC_DRIVER_CLASS_NAME|org.postgresql.Driver|\" ${PXF_CONF_DIR}/servers/database/jdbc-site.xml &&
        sed -i \"s|YOUR_DATABASE_JDBC_URL|jdbc:postgresql://mdw:5432/pxfautomation|\" ${PXF_CONF_DIR}/servers/database/jdbc-site.xml &&
        sed -i \"s|YOUR_DATABASE_JDBC_USER|gpadmin|\" ${PXF_CONF_DIR}/servers/database/jdbc-site.xml &&
        sed -i \"s|YOUR_DATABASE_JDBC_PASSWORD||\" ${PXF_CONF_DIR}/servers/database/jdbc-site.xml &&
        cp ~gpadmin/report.sql ${PXF_CONF_DIR}/servers/database/ &&
        cp ${PXF_CONF_DIR}/servers/database/jdbc-site.xml ${PXF_CONF_DIR}/servers/database/testuser-user.xml &&
        sed -i \"s|pxfautomation|template1|\" ${PXF_CONF_DIR}/servers/database/testuser-user.xml &&
        mkdir -p ${PXF_CONF_DIR}/servers/db-session-params &&
        cp ${PXF_CONF_DIR}/templates/jdbc-site.xml ${PXF_CONF_DIR}/servers/db-session-params/ &&
        sed -i \"s|YOUR_DATABASE_JDBC_DRIVER_CLASS_NAME|org.postgresql.Driver|\" ${PXF_CONF_DIR}/servers/db-session-params/jdbc-site.xml &&
        sed -i \"s|YOUR_DATABASE_JDBC_URL|jdbc:postgresql://mdw:5432/pxfautomation|\" ${PXF_CONF_DIR}/servers/db-session-params/jdbc-site.xml &&
        sed -i \"s|YOUR_DATABASE_JDBC_USER||\" ${PXF_CONF_DIR}/servers/db-session-params/jdbc-site.xml &&
        sed -i \"s|YOUR_DATABASE_JDBC_PASSWORD||\" ${PXF_CONF_DIR}/servers/db-session-params/jdbc-site.xml &&
        sed -i \"s|</configuration>|<property><name>jdbc.session.property.client_min_messages</name><value>debug1</value></property></configuration>|\" ${PXF_CONF_DIR}/servers/db-session-params/jdbc-site.xml &&
        sed -i \"s|</configuration>|<property><name>jdbc.session.property.default_statistics_target</name><value>123</value></property></configuration>|\" ${PXF_CONF_DIR}/servers/db-session-params/jdbc-site.xml &&
        mkdir -p ${PXF_CONF_DIR}/servers/db-hive &&
        cp ${PXF_CONF_DIR}/templates/jdbc-site.xml ${PXF_CONF_DIR}/servers/db-hive/ &&
        sed -i \"s|YOUR_DATABASE_JDBC_DRIVER_CLASS_NAME|org.apache.hive.jdbc.HiveDriver|\" ${PXF_CONF_DIR}/servers/db-hive/jdbc-site.xml &&
        sed -i \"s|YOUR_DATABASE_JDBC_URL|jdbc:hive2://${HADOOP_HOSTNAME}:10000/default|\" ${PXF_CONF_DIR}/servers/db-hive/jdbc-site.xml &&
        sed -i \"s|YOUR_DATABASE_JDBC_USER||\" ${PXF_CONF_DIR}/servers/db-hive/jdbc-site.xml &&
        sed -i \"s|YOUR_DATABASE_JDBC_PASSWORD||\" ${PXF_CONF_DIR}/servers/db-hive/jdbc-site.xml &&
        cp ~gpadmin/hive-report.sql ${PXF_CONF_DIR}/servers/db-hive/ &&
        ${GPHOME}/pxf/bin/pxf cluster sync"
}

function run_pxf_automation() {

	if [[ $HIVE_VERSION == "2" ]]; then
		sed -i "s|<hiveBaseHdfsDirectory>/hive/warehouse/</hiveBaseHdfsDirectory>|<hiveBaseHdfsDirectory>/user/hive/warehouse/</hiveBaseHdfsDirectory>|g" pxf_src/automation/src/test/resources/sut/MultiNodesCluster.xml
	fi

	sed -i "s/GPDB_IP/${gpdb_master}/g" pxf_src/automation/src/test/resources/sut/MultiNodesCluster.xml
	sed -i "s/>hadoop</>${HADOOP_HOSTNAME}</g" pxf_src/automation/src/test/resources/sut/MultiNodesCluster.xml

	if [[ $KERBEROS == true ]]; then
	  DATAPROC_DIR=$( find /tmp/build/ -name dataproc_env_files )
    REALM=$(cat "${DATAPROC_DIR}/REALM")
    REALM=${REALM^^} # make sure REALM is up-cased, down-case below for hive principal
    KERBERIZED_HADOOP_URI="hive/${HADOOP_HOSTNAME}.${REALM,,}@${REALM};saslQop=auth-conf"
	  sed -i -e "s|</hdfs>|<hadoopRoot>$DATAPROC_DIR</hadoopRoot></hdfs>|g" \
	    -e "s|</cluster>|<testKerberosPrincipal>gpadmin@${REALM}</testKerberosPrincipal></cluster>|g" \
	    -e "s|</hive>|<kerberosPrincipal>${KERBERIZED_HADOOP_URI}</kerberosPrincipal><userName>gpadmin</userName></hive>|g" \
      pxf_src/automation/src/test/resources/sut/MultiNodesCluster.xml
    ssh gpadmin@mdw "
      sed -i -e 's|\(jdbc:hive2://${HADOOP_HOSTNAME}:10000/default\)|\1;principal=${KERBERIZED_HADOOP_URI}|g' ${PXF_CONF_DIR}/servers/db-hive/jdbc-site.xml
      ${GPHOME}/pxf/bin/pxf cluster sync
    "
	  sudo mkdir -p /etc/security/keytabs
	  sudo cp "$DATAPROC_DIR"/pxf.service.keytab /etc/security/keytabs/gpadmin.headless.keytab
	  sudo chown gpadmin:gpadmin /etc/security/keytabs/gpadmin.headless.keytab
	  sudo cp "$DATAPROC_DIR"/krb5.conf /etc/krb5.conf
	fi

	sed -i 's/sutFile=default.xml/sutFile=MultiNodesCluster.xml/g' pxf_src/automation/jsystem.properties
	chown -R gpadmin:gpadmin /home/gpadmin pxf_src/automation

	cat > /home/gpadmin/run_pxf_automation_test.sh <<EOF
set -exo pipefail

source ${GPHOME}/greenplum_path.sh

export PATH=\$PATH:${GPHD_ROOT}/bin:${HADOOP_ROOT}/bin:${HBASE_ROOT}/bin:${HIVE_ROOT}/bin:${ZOOKEEPER_ROOT}/bin
export GPHOME=/usr/local/greenplum-db-devel
export PXF_HOME=${GPHOME}/pxf
export PGHOST=mdw
export PGPORT=5432

cd pxf_src/automation
make GROUP=${GROUP}

exit 0
EOF

	chown gpadmin:gpadmin /home/gpadmin/run_pxf_automation_test.sh
	chmod a+x /home/gpadmin/run_pxf_automation_test.sh

	if [[ ${ACCEPTANCE} == true ]]; then
		echo Acceptance test pipeline
		close_ssh_tunnels
		exit 1
	fi

	su gpadmin -c "bash /home/gpadmin/run_pxf_automation_test.sh"
}

function _main() {

	cp -R cluster_env_files/.ssh/* /root/.ssh
	# we need word boundary in case of standby master (smdw)
	gpdb_master=$(grep < cluster_env_files/etc_hostfile '\bmdw' | awk '{print $1}')

	gpdb_segments=$(grep < cluster_env_files/etc_hostfile -e sdw | awk '{print $1}')
	if [[ -d dataproc_env_files ]]; then
		HADOOP_HOSTNAME=$(cat dataproc_env_files/name)
		hadoop_ip=$(getent hosts "$HADOOP_HOSTNAME" | awk '{ print $1 }')
	else
		HADOOP_HOSTNAME=hadoop
		hadoop_ip=$(grep < cluster_env_files/etc_hostfile edw0 | awk '{print $1}')
	fi

	install_gpdb_binary # Installs the GPDB Binary on the container
	setup_gpadmin_user
	install_pxf_server
	init_and_configure_pxf_server
	remote_access_to_gpdb

	open_ssh_tunnels
	configure_local_hdfs

	# widen access to mdw to all nodes in the cluster for JDBC test
	update_pghba_conf "${gpdb_segments[@]}"

	setup_pxf_on_cluster

	run_pxf_automation
	close_ssh_tunnels
}

_main
