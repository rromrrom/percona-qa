#!/bin/bash
# Created by Raghavendra Prabhu <raghavendra.prabhu@percona.com>
# Updated by Ramesh Sivaraman, Percona LLC

ulimit -c unlimited
export MTR_MAX_SAVE_CORE=5

set +e
echo "Killing existing mysqld"
pgrep -f mysqld

pkill -f mysqld
sleep 10
pgrep mysqld || pkill -9 -f mysqld

sleep 5
SCRIPT_PWD=$(cd `dirname $0` && pwd)
WORKDIR=$1
ROOT_FS=$WORKDIR
MYSQLD_START_TIMEOUT=180

# Table for sysbench oltp rw test
STABLE="test.sbtest1"

if [ ! -d ${ROOT_FS}/test_db ]; then
  pushd ${ROOT_FS}
  git clone https://github.com/datacharmer/test_db.git
  popd
fi

function create_emp_db()
{
  DB_NAME=$1
  SE_NAME=$2
  SQL_FILE=$3
  pushd ${ROOT_FS}/test_db
  cat ${ROOT_FS}/test_db/$SQL_FILE \
   | sed -e "s|DROP DATABASE IF EXISTS employees|DROP DATABASE IF EXISTS ${DB_NAME}|" \
   | sed -e "s|CREATE DATABASE IF NOT EXISTS employees|CREATE DATABASE IF NOT EXISTS ${DB_NAME}|" \
   | sed -e "s|USE employees|USE ${DB_NAME}|" \
   | sed -e "s|set default_storage_engine = InnoDB|set default_storage_engine = ${SE_NAME}|" \
   > ${ROOT_FS}/test_db/${DB_NAME}_${SE_NAME}.sql
  $MYSQL_BASEDIR1/bin/mysql --socket=/tmp/node1.socket -u root < ${ROOT_FS}/test_db/${DB_NAME}_${SE_NAME}.sql || true
  popd
}

# Parameter of parameterized build
if [ -z ${BUILD_NUMBER} ]; then
  BUILD_NUMBER=1001
fi
if [ -z $SDURATION ]; then
  SDURATION=30
fi
if [ -z $AUTOINC ]; then
  AUTOINC=off
fi
if [ -z ${TSIZE} ]; then
  TSIZE=50
fi
if [ -z ${TCOUNT} ]; then
  TCOUNT=5
fi
if [ -z ${NUMT} ]; then
  NUMT=16
fi
if [ -z ${DIR} ]; then
  DIR=0
fi
if [ -z ${STEST} ]; then
  STEST=oltp
fi
if [ -z $SST_METHOD ]; then
  SST_METHOD="rsync"
fi

# This parameter selects on which nodes the sysbench run will take place
if [[ $DIR -eq 0 ]]; then
  sockets="/tmp/node1.socket,/tmp/node2.socket,/tmp/node3.socket"
elif [[ $DIR -eq 1 ]]; then
  sockets="/tmp/node1.socket"
elif [[ $DIR -eq 2 ]]; then
  sockets="/tmp/node2.socket"
elif [[ $DIR -eq 3 ]]; then
  sockets="/tmp/node3.socket"
fi

cd $WORKDIR

if [[ $SST_METHOD == xtrabackup ]]; then
  SST_METHOD="xtrabackup-v2"
  TAR=`ls -1ct percona-xtrabackup*.tar.gz | head -n1`
  tar -xf $TAR
  BBASE="$(tar tf $TAR | head -1 | tr -d '/')"
  export PATH="$ROOT_FS/$BBASE/bin:$PATH"
fi

count=$(ls -1ct Percona-XtraDB-Cluster-5.7*.tar.gz | wc -l)
if [[ $count -gt 1 ]]; then
  for dirs in `ls -1ct Percona-XtraDB-Cluster-5.7*.tar.gz | tail -n +2`; do
     rm -rf $dirs
  done
fi
find . -maxdepth 1 -type d -name 'Percona-XtraDB-Cluster-5.7*' -exec rm -rf {} \+

count=$(ls -1ct Percona-XtraDB-Cluster-5.6*.tar.gz | wc -l)
if [[ $count -gt 1 ]]; then
  for dirs in `ls -1ct Percona-XtraDB-Cluster-5.6*.tar.gz | tail -n +2`; do
    rm -rf $dirs
  done
fi
find . -maxdepth 1 -type d -name 'Percona-XtraDB-Cluster-5.6*' -exec rm -rf {} \+

echo "Removing older directories"
find . -maxdepth 1 -type d -mtime +10 -exec rm -rf {} \+

echo "Removing their symlinks"
find . -maxdepth 1 -type l -mtime +10 -delete

TAR=`ls -1ct Percona-XtraDB-Cluster-5.6*.tar.gz | head -n1`
BASE1="$(tar tf $TAR | head -1 | tr -d '/')"
tar -xf $TAR

TAR=`ls -1ct Percona-XtraDB-Cluster-5.7*.tar.gz | head -n1`
BASE2="$(tar tf $TAR | head -1 | tr -d '/')"
tar -xf $TAR

LPATH=${SPATH:-/usr/share/doc/sysbench/tests/db}

# User settings
WORKDIR="${ROOT_FS}/$BUILD_NUMBER"
mkdir -p $WORKDIR/logs

MYSQL_BASEDIR1="${ROOT_FS}/$BASE1"
MYSQL_BASEDIR2="${ROOT_FS}/$BASE2"
export MYSQL_VARDIR="$WORKDIR/mysqldir"
mkdir -p $MYSQL_VARDIR

SDIR="$LPATH"
SRESULTS="$WORKDIR/sresults"

mkdir -p $SRESULTS

echo "Workdir: $WORKDIR"
echo "Basedirs: $MYSQL_BASEDIR1 $MYSQL_BASEDIR2"

ADDR="127.0.0.1"
RPORT=$(( RANDOM%21 + 10 ))
RBASE1="$(( RPORT*1000 ))"
echo "Setting RBASE to $RBASE1"
RADDR1="$ADDR:$(( RBASE1 + 7 ))"
LADDR1="$ADDR:$(( RBASE1 + 8 ))"

RBASE2="$(( RBASE1 + 100 ))"
RADDR2="$ADDR:$(( RBASE2 + 7 ))"
LADDR2="$ADDR:$(( RBASE2 + 8 ))"

RBASE3="$(( RBASE2 + 100 ))"
RADDR3="$ADDR:$(( RBASE3 + 7 ))"
LADDR3="$ADDR:$(( RBASE3 + 8 ))"

SUSER=root
SPASS=

node1="${MYSQL_VARDIR}/node1"
rm -rf $node1;mkdir -p $node1
node2="${MYSQL_VARDIR}/node2"
rm -rf $node2;mkdir -p $node2
node3="${MYSQL_VARDIR}/node3"
rm -rf $node3;mkdir -p $node3

EXTSTATUS=0

if [[ $MEM -eq 1 ]]; then
  MEMOPT="--mem"
else
  MEMOPT=""
fi

archives() {
  tar czf $ROOT_FS/results-${BUILD_NUMBER}.tar.gz ./${BUILD_NUMBER}/logs || true
  rm -rf $WORKDIR
}

trap archives EXIT KILL

if [[ -n ${EXTERNALS:-} ]]; then
  EXTOPTS="$EXTERNALS"
else
  EXTOPTS=""
fi

if [[ $DEBUG -eq 1 ]]; then
  DBG="--mysqld=--wsrep-debug=1"
else
  DBG=""
fi

check_script(){
  MPID=$1
  if [ ${MPID} -ne 0 ]; then echo "Assert! ${MPID} empty. Terminating!"; exit 1; fi
}

#
# Common functions
#
show_node_status(){
  local FUN_NODE_NR=$1
  local FUN_MYSQL_BASEDIR=$2
  local SHOW_SYSBENCH_COUNT=$3

  echo -e "Showing status of node${FUN_NODE_NR}:"
  ${FUN_MYSQL_BASEDIR}/bin/mysql -S /tmp/node${FUN_NODE_NR}.socket -u root -e "show global variables like 'version';"
  ${FUN_MYSQL_BASEDIR}/bin/mysql -S /tmp/node${FUN_NODE_NR}.socket -u root -e "show global status like 'wsrep_cluster_status';"
  ${FUN_MYSQL_BASEDIR}/bin/mysql -S /tmp/node${FUN_NODE_NR}.socket -u root -e "show global status like 'wsrep_connected';"
  ${FUN_MYSQL_BASEDIR}/bin/mysql -S /tmp/node${FUN_NODE_NR}.socket -u root -e "show global status like 'wsrep_ready';"
  ${FUN_MYSQL_BASEDIR}/bin/mysql -S /tmp/node${FUN_NODE_NR}.socket -u root -e "show global status like 'wsrep_local_state_comment';"

  if [ ${SHOW_SYSBENCH_COUNT} -eq 1 ]; then
    echo "Number of rows in table $STABLE on node${FUN_NODE_NR}"
    ${FUN_MYSQL_BASEDIR}/bin/mysql -S /tmp/node${FUN_NODE_NR}.socket -u root -e "select count(*) from $STABLE;"
  fi
}

pxc_start_node(){
  local FUN_NODE_NR=$1
  local FUN_NODE_VER=$2
  local FUN_NODE_PATH=$3
  local FUN_CLUSTER_ADDRESS=$4
  local FUN_WSREP_PROVIDER_OPTIONS=$5
  local FUN_RBASE=$6
  local FUN_WSREP_PROVIDER=$7
  local FUN_LOG_ERR=$8
  local FUN_BASE_DIR=$9

  echo "Starting PXC-${FUN_NODE_VER} node${FUN_NODE_NR}"
  ${FUN_BASE_DIR}/bin/mysqld --no-defaults --defaults-group-suffix=.${FUN_NODE_NR} \
    --basedir=${FUN_BASE_DIR} --datadir=${FUN_NODE_PATH} \
    --loose-debug-sync-timeout=600 --skip-performance-schema \
    --innodb_file_per_table --innodb_autoinc_lock_mode=2 --innodb_locks_unsafe_for_binlog=1 \
    --wsrep-provider=${FUN_WSREP_PROVIDER} \
    --wsrep_cluster_address=${FUN_CLUSTER_ADDRESS} \
    --wsrep_node_incoming_address=$ADDR \
    --wsrep_provider_options=${FUN_WSREP_PROVIDER_OPTIONS} \
    --wsrep_sst_method=$SST_METHOD --wsrep_sst_auth=$SUSER:$SPASS \
    --wsrep_node_address=$ADDR --innodb_flush_method=O_DIRECT \
    --query_cache_type=0 --query_cache_size=0 \
    --innodb_flush_log_at_trx_commit=0 --innodb_buffer_pool_size=500M \
    --innodb_log_file_size=500M \
    --core-file --loose-new --sql-mode=no_engine_substitution \
    --loose-innodb --secure-file-priv= --loose-innodb-status-file=1 \
    --log-error=${FUN_LOG_ERR} \
    --socket=/tmp/node${FUN_NODE_NR}.socket --log-output=none \
    --port=${FUN_RBASE} --server-id=${FUN_NODE_NR} --wsrep_slave_threads=8 > ${FUN_LOG_ERR} 2>&1 &

  for X in $(seq 0 ${MYSQLD_START_TIMEOUT}); do
    sleep 1
    if $FUN_BASE_DIR/bin/mysqladmin -uroot -S/tmp/node${FUN_NODE_NR}.socket ping > /dev/null 2>&1; then
      break
    fi
  done
  if $FUN_BASE_DIR/bin/mysqladmin -uroot -S/tmp/node${FUN_NODE_NR}.socket ping > /dev/null 2>&1; then
    echo "PXC node${FUN_NODE_NR} started ok.."
  else
    echo "PXC node${FUN_NODE_NR} startup failed.. Please check error log: ${FUN_LOG_ERR}"
  fi

  sleep 10
}

pxc_upgrade_node(){
  local FUN_NODE_NR=$1
  local FUN_NODE_VER=$2
  local FUN_NODE_PATH=$3
  local FUN_RBASE=$4
  local FUN_LOG_ERR=$5
  local FUN_BASE_DIR=$6

  echo -e "\n\n#### Upgrade node${FUN_NODE_NR} to the version ${FUN_NODE_VER}\n"
  echo "Shutting down node${FUN_NODE_NR} after SST"
  ${FUN_BASE_DIR}/bin/mysqladmin  --socket=/tmp/node${FUN_NODE_NR}.socket -u root shutdown
  if [[ $? -ne 0 ]]; then
    echo "Shutdown failed for node${FUN_NODE_NR}"
    exit 1
  fi

  sleep 10

  echo "Starting PXC-${FUN_NODE_VER} node${FUN_NODE_NR}"
  ${FUN_BASE_DIR}/bin/mysqld --no-defaults --defaults-group-suffix=.${FUN_NODE_NR} \
    --basedir=${FUN_BASE_DIR} --datadir=${FUN_NODE_PATH} \
    --loose-debug-sync-timeout=600 --skip-performance-schema \
    --innodb_file_per_table --innodb_autoinc_lock_mode=2 --innodb_locks_unsafe_for_binlog=1 \
    --wsrep-provider='none' --innodb_flush_method=O_DIRECT \
    --query_cache_type=0 --query_cache_size=0 \
    --innodb_flush_log_at_trx_commit=0 --innodb_buffer_pool_size=500M \
    --innodb_log_file_size=500M \
    --core-file --loose-new --sql-mode=no_engine_substitution \
    --loose-innodb --secure-file-priv= --loose-innodb-status-file=1 \
    --log-error=${FUN_LOG_ERR} \
    --socket=/tmp/node${FUN_NODE_NR}.socket --log-output=none \
    --port=${FUN_RBASE} --server-id=${FUN_NODE_NR} --wsrep_slave_threads=8 > ${FUN_LOG_ERR} 2>&1 &

  for X in $(seq 0 ${MYSQLD_START_TIMEOUT}); do
    sleep 1
    if ${FUN_BASE_DIR}/bin/mysqladmin -uroot -S/tmp/node${FUN_NODE_NR}.socket ping > /dev/null 2>&1; then
      break
    fi
  done
  if ${FUN_BASE_DIR}/bin/mysqladmin -uroot -S/tmp/node${FUN_NODE_NR}.socket ping > /dev/null 2>&1; then
    echo "PXC node${FUN_NODE_NR} re-started for upgrade.."
  else
    echo "PXC node${FUN_NODE_NR} startup for upgrade failed... Please check error log: ${FUN_LOG_ERR}"
  fi

  sleep 10

  # Run mysql_upgrade
  ${FUN_BASE_DIR}/bin/mysql_upgrade -S /tmp/node${FUN_NODE_NR}.socket -u root 2>&1 | tee $WORKDIR/logs/mysql_upgrade_node${FUN_NODE_NR}.log
  if [[ $? -ne 0 ]]; then
    echo "mysql upgrade on node${FUN_NODE_NR} failed"
    exit 1
  fi

  echo "Shutting down node${FUN_NODE_NR} after upgrade"
  ${FUN_BASE_DIR}/bin/mysqladmin  --socket=/tmp/node${FUN_NODE_NR}.socket -u root shutdown > /dev/null 2>&1

  if [[ $? -ne 0 ]]; then
    echo "Shutdown after upgrade failed for node${FUN_NODE_NR}"
    exit 1
  fi

  sleep 10
}

sysbench_run(){
  local FUN_NODE_NR=$1

  if [[ ! -e $SDIR/${STEST}.lua ]]; then
    pushd /tmp
    rm $STEST.lua || true
    wget -O $STEST.lua https://github.com/Percona-QA/sysbench/tree/0.5/sysbench/tests/db/${STEST}.lua
    SDIR=/tmp/
    popd
  fi

  set -x
  sysbench --mysql-table-engine=innodb --num-threads=$NUMT --report-interval=10 --oltp-auto-inc=$AUTOINC --max-time=$SDURATION --max-requests=1870000000 \
      --test=$SDIR/$STEST.lua --init-rng=on --oltp_index_updates=10 --oltp_non_index_updates=10 --oltp_distinct_ranges=15 --oltp_order_ranges=15 --oltp_tables_count=$TCOUNT --mysql-db=test \
      --mysql-user=root --db-driver=mysql --mysql-socket=$sockets \
      run 2>&1 | tee $WORKDIR/logs/sysbench_rw_run_node${FUN_NODE_NR}.txt
  #check_script $?

  if [[ ${PIPESTATUS[0]} -ne 0 ]];then
    echo "Sysbench run on node${FUN_NODE_NR} failed"
    EXTSTATUS=1
  fi
  set +x
}

#
# Install cluster from previous version
#
echo -e "\n\n#### Installing cluster from previous version\n"
${MYSQL_BASEDIR1}/scripts/mysql_install_db --no-defaults --basedir=${MYSQL_BASEDIR1} --datadir=$node1 > $WORKDIR/logs/node1-pre.err 2>&1 || exit 1;
pxc_start_node 1 "5.6" "$node1" "gcomm://" "gmcast.listen_addr=tcp://${LADDR1}" "$RBASE1" "${MYSQL_BASEDIR1}/lib/libgalera_smm.so" "$WORKDIR/logs/node1-pre.err" "${MYSQL_BASEDIR1}"

${MYSQL_BASEDIR1}/scripts/mysql_install_db --no-defaults --basedir=${MYSQL_BASEDIR1} --datadir=$node2 > $WORKDIR/logs/node2-pre.err 2>&1 || exit 1;
pxc_start_node 2 "5.6" "$node2" "gcomm://$LADDR1,gcomm://$LADDR3" "gmcast.listen_addr=tcp://${LADDR2}" "$RBASE2" "${MYSQL_BASEDIR1}/lib/libgalera_smm.so" "$WORKDIR/logs/node2-pre.err" "${MYSQL_BASEDIR1}"

${MYSQL_BASEDIR1}/scripts/mysql_install_db --no-defaults --basedir=${MYSQL_BASEDIR1} --datadir=$node3 > $WORKDIR/logs/node3-pre.err 2>&1 || exit 1;
pxc_start_node 3 "5.6" "$node3" "gcomm://$LADDR1,gcomm://$LADDR2" "gmcast.listen_addr=tcp://${LADDR3}" "$RBASE3" "${MYSQL_BASEDIR1}/lib/libgalera_smm.so" "$WORKDIR/logs/node3-pre.err" "${MYSQL_BASEDIR1}"

#
# Sysbench run on previous version on node1
#
## Prepare/setup
echo -e "\n\n#### Sysbench run on previous version on node1\n"

sysbench --test=$SDIR/parallel_prepare.lua --report-interval=10  --oltp-auto-inc=$AUTOINC --mysql-engine-trx=yes --mysql-table-engine=innodb \
    --oltp-table-size=$TSIZE --oltp_tables_count=$TCOUNT --mysql-db=test --mysql-user=root \
    --db-driver=mysql --mysql-socket=/tmp/node1.socket prepare 2>&1 | tee $WORKDIR/logs/sysbench_prepare.txt
#check_script $?

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
   echo "Sysbench prepare failed"
   exit 1
fi

echo "Loading sakila test database on node1"
$MYSQL_BASEDIR1/bin/mysql --socket=/tmp/node1.socket -u root < ${SCRIPT_PWD}/sample_db/sakila.sql
check_script $?

echo "Loading world test database on node1"
$MYSQL_BASEDIR1/bin/mysql --socket=/tmp/node1.socket -u root < ${SCRIPT_PWD}/sample_db/world.sql
check_script $?

echo "Loading employees database with innodb engine.."
create_emp_db employee_1 innodb employees.sql
check_script $?

echo "Loading employees partitioned database with innodb engine.."
create_emp_db employee_2 innodb employees_partitioned.sql
check_script $?

#
# Upgrading node2 to the new version
#
echo -e "\n\n#### Show node2 status before upgrade\n"
show_node_status 2 $MYSQL_BASEDIR1 0
echo "Running upgrade on node2"
pxc_upgrade_node 2 "5.7" "$node2" "$RBASE2" "$WORKDIR/logs/node2-upgrade.err" "${MYSQL_BASEDIR2}"
echo "Starting node2 after upgrade"
pxc_start_node 2 "5.7" "$node2" "gcomm://$LADDR1,gcomm://$LADDR3" "gmcast.listen_addr=tcp://$LADDR2;socket.checksum=1" "$RBASE2" "${MYSQL_BASEDIR2}/lib/libgalera_smm.so" "$WORKDIR/logs/node2-after_upgrade.err" "${MYSQL_BASEDIR2}"

# Show nodes status after node2 upgrade and before Sysbench run
echo -e "\n\n#### Showing nodes status after node2 upgrade\n"
show_node_status 1 $MYSQL_BASEDIR1 0
show_node_status 2 $MYSQL_BASEDIR2 0
show_node_status 3 $MYSQL_BASEDIR1 0

echo -e "\n\n#### Sysbench OLTP RW run after node2 upgrade\n"
sysbench_run 2
#
# End node2 upgrade and check
#

sleep 10

#
# Upgrading node3 to the new version
#
echo -e "\n\n#### Show node3 status before upgrade\n"
show_node_status 3 $MYSQL_BASEDIR1 1
echo "Running upgrade on node3"
pxc_upgrade_node 3 "5.7" "$node3" "$RBASE3" "$WORKDIR/logs/node3-upgrade.err" "${MYSQL_BASEDIR2}"
echo "Starting node3 after upgrade"
pxc_start_node 3 "5.7" "$node3" "gcomm://$LADDR1,gcomm://$LADDR2" "gmcast.listen_addr=tcp://$LADDR3;socket.checksum=1" "$RBASE3" "${MYSQL_BASEDIR2}/lib/libgalera_smm.so" "$WORKDIR/logs/node3-after_upgrade.err" "${MYSQL_BASEDIR2}"

# Show nodes status after node3 upgrade and before Sysbench run
echo -e "\n\n#### Showing nodes status before node3 upgrade\n"
show_node_status 1 $MYSQL_BASEDIR1 1
show_node_status 2 $MYSQL_BASEDIR2 1
show_node_status 3 $MYSQL_BASEDIR2 1

echo -e "\n\n#### Sysbench OLTP RW run after node3 upgrade\n"
sysbench_run 3

# Show nodes status after node3 upgrade and after Sysbench run
echo -e "\n\n#### Showing nodes status after node3 upgrade\n"
show_node_status 1 $MYSQL_BASEDIR1 1
show_node_status 2 $MYSQL_BASEDIR2 1
show_node_status 3 $MYSQL_BASEDIR2 1
#
# End node3 upgrade and check
#

sleep 10

#
# Upgrading node1 to the new version
#
echo -e "\n\n#### Show node1 status before upgrade\n"
show_node_status 1 $MYSQL_BASEDIR1 1
echo "Running upgrade on node1"
pxc_upgrade_node 1 "5.7" "$node1" "$RBASE1" "$WORKDIR/logs/node1-upgrade.err" "${MYSQL_BASEDIR2}"
echo "Starting node1 after upgrade"
pxc_start_node 1 "5.7" "$node1" "gcomm://$LADDR2,gcomm://$LADDR3" "gmcast.listen_addr=tcp://$LADDR1;socket.checksum=1" "$RBASE1" "${MYSQL_BASEDIR2}/lib/libgalera_smm.so" "$WORKDIR/logs/node1-after_upgrade.err" "${MYSQL_BASEDIR2}"

# Show nodes status after node1 upgrade and before Sysbench run
echo -e "\n\n#### Showing nodes status before node1 upgrade\n"
show_node_status 1 $MYSQL_BASEDIR2 1
show_node_status 2 $MYSQL_BASEDIR2 1
show_node_status 3 $MYSQL_BASEDIR2 1

echo -e "\n\n#### Sysbench OLTP RW run after node1 upgrade\n"
sysbench_run 1

# Show nodes status after node1 upgrade and after Sysbench run
echo -e "\n\n#### Showing nodes status after node1 upgrade\n"
show_node_status 1 $MYSQL_BASEDIR2 1
show_node_status 2 $MYSQL_BASEDIR2 1
show_node_status 3 $MYSQL_BASEDIR2 1
#
# End node1 upgrade and check
#

#
# Taking backup for downgrade testing
#
echo -e "\n\n#### Backup before downgrade test\n"

$MYSQL_BASEDIR2/bin/mysqldump --set-gtid-purged=OFF  --triggers --routines --socket=/tmp/node1.socket -uroot --databases `$MYSQL_BASEDIR2/bin/mysql --socket=/tmp/node1.socket -uroot -Bse "SELECT GROUP_CONCAT(schema_name SEPARATOR ' ') FROM information_schema.schemata WHERE schema_name NOT IN ('mysql','performance_schema','information_schema','sys','mtr');"` > $WORKDIR/dbdump.sql 2>&1
check_script $?

#
# Downgrade testing
#
echo -e "\n\n#### Downgrade test\n"
$MYSQL_BASEDIR2/bin/mysqladmin  --socket=/tmp/node1.socket -u root shutdown  > /dev/null 2>&1
$MYSQL_BASEDIR2/bin/mysqladmin  --socket=/tmp/node2.socket -u root shutdown  > /dev/null 2>&1
$MYSQL_BASEDIR2/bin/mysqladmin  --socket=/tmp/node3.socket -u root shutdown  > /dev/null 2>&1

rm -Rf $node1/* $node2/* $node3/*

${MYSQL_BASEDIR1}/scripts/mysql_install_db --no-defaults --basedir=${MYSQL_BASEDIR1} --datadir=$node1 > $WORKDIR/logs/node1-downgrade.err 2>&1 || exit 1;
pxc_start_node 1 "5.6" "$node1" "gcomm://" "gmcast.listen_addr=tcp://${LADDR1}" "$RBASE1" "${MYSQL_BASEDIR1}/lib/libgalera_smm.so" "$WORKDIR/logs/node1-downgrade.err" "${MYSQL_BASEDIR1}"

${MYSQL_BASEDIR1}/scripts/mysql_install_db --no-defaults --basedir=${MYSQL_BASEDIR1} --datadir=$node2 > $WORKDIR/logs/node2-downgrade.err 2>&1 || exit 1;
pxc_start_node 2 "5.6" "$node2" "gcomm://$LADDR1,gcomm://$LADDR3" "gmcast.listen_addr=tcp://${LADDR2}" "$RBASE2" "${MYSQL_BASEDIR1}/lib/libgalera_smm.so" "$WORKDIR/logs/node2-downgrade.err" "${MYSQL_BASEDIR1}"

${MYSQL_BASEDIR1}/scripts/mysql_install_db --no-defaults --basedir=${MYSQL_BASEDIR1} --datadir=$node3 > $WORKDIR/logs/node3-downgrade.err 2>&1 || exit 1;
pxc_start_node 3 "5.6" "$node3" "gcomm://$LADDR1,gcomm://$LADDR2" "gmcast.listen_addr=tcp://${LADDR3}" "$RBASE3" "${MYSQL_BASEDIR1}/lib/libgalera_smm.so" "$WORKDIR/logs/node3-downgrade.err" "${MYSQL_BASEDIR1}"

# Import database
${MYSQL_BASEDIR1}/bin/mysql --socket=/tmp/node1.socket -uroot < $WORKDIR/dbdump.sql 2>&1

CHECK_DBS=`$MYSQL_BASEDIR1/bin/mysql --socket=/tmp/node1.socket -uroot -Bse "SELECT GROUP_CONCAT(schema_name SEPARATOR ' ') FROM information_schema.schemata WHERE schema_name NOT IN ('mysql','performance_schema','information_schema','sys','mtr');"`

echo "Checking table status..."
${MYSQL_BASEDIR1}/bin/mysqlcheck -uroot --socket=/tmp/node1.socket --check-upgrade --databases $CHECK_DBS 2>&1
check_script $?

# Show nodes status after downgrade
echo -e "\n\n#### Showing nodes status after cluster downgrade\n"
show_node_status 1 $MYSQL_BASEDIR1 1
show_node_status 2 $MYSQL_BASEDIR1 1
show_node_status 3 $MYSQL_BASEDIR1 1

$MYSQL_BASEDIR1/bin/mysqladmin --socket=/tmp/node1.socket -u root shutdown > /dev/null 2>&1
$MYSQL_BASEDIR1/bin/mysqladmin --socket=/tmp/node2.socket -u root shutdown > /dev/null 2>&1
$MYSQL_BASEDIR1/bin/mysqladmin --socket=/tmp/node3.socket -u root shutdown > /dev/null 2>&1

exit $EXTSTATUS
