#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

MAKE_THREADS=1      # Number of build threads. There may be a bug with >1 settings
WITH_ROCKSDB=1      # 0 or 1  # Please note when building the facebook-mysql-5.6 tree this setting is automatically ignored
                              # For daily builds of fb tree (opt and debug) also see http://jenkins.percona.com/job/fb-mysql-5.6/
                              # This is also auto-turned off for all 5.5 and 5.6 builds 
USE_CLANG=0         # Use the clang compiler instead of gcc
CLANG_LOCATION="/home/roel/third_party/llvm-build/Release+Asserts/bin/clang"
CLANGPP_LOCATION="${CLANG_LOCATION}++"

# To install the latest clang from Chromium devs;
# sudo yum remove clang    # Or sudo apt-get remove clang
# cd ~
# mkdir TMP_CLANG
# cd TMP_CLANG
# git clone https://chromium.googlesource.com/chromium/src/tools/clang
# cd ..
# TMP_CLANG/clang/scripts/update.py

if [ ! -r VERSION ]; then
  echo "Assert: 'VERSION' file not found!"
fi

MYSQL_VERSION_MAJOR=$(grep "MYSQL_VERSION_MAJOR" VERSION | sed 's|.*=||')
MYSQL_VERSION_MINOR=$(grep "MYSQL_VERSION_MINOR" VERSION | sed 's|.*=||')
if [ "$MYSQL_VERSION_MAJOR" == "5" ]; then
  if [ "$MYSQL_VERSION_MINOR" == "5" -o "$MYSQL_VERSION_MINOR" == "6" ]; then
    WITH_ROCKSDB=0  # This works fine for MS and PS but is not tested for MD
  fi
fi

ASAN=
if [ "${1}" != "" ]; then
  echo "Building with ASAN enabled"
  ASAN="-DWITH_ASAN=ON"
fi

DATE=$(date +'%d%m%y')
PREFIX=
MS=0
FB=0

if [ ! -d rocksdb ]; then  # MS, PS
  VERSION_EXTRA="$(grep "MYSQL_VERSION_EXTRA=" VERSION | sed 's|MYSQL_VERSION_EXTRA=||;s|[ \t]||g')"
  if [ "${VERSION_EXTRA}" == "" -o "${VERSION_EXTRA}" == "-dmr" ]; then  # MS has no extra version number, or shows '-dmr' (exactly and only) in this place
    MS=1
    PREFIX="MS${DATE}"
  else
    PREFIX="PS${DATE}"
  fi
else
  PREFIX="FB${DATE}"
  FB=1
fi

CLANG=
if [ $USE_CLANG -eq 1 ]; then
  CLANG="-DCMAKE_C_COMPILER=$CLANG_LOCATION -DCMAKE_CXX_COMPILER=$CLANGPP_LOCATION"
fi
FLAGS=
if [ $FB -eq 1 ]; then
  FLAGS='-DCMAKE_CXX_FLAGS="-march=native"'  # Default for FB tree
fi

CURPATH=$(echo $PWD | sed 's|.*/||')

cd ..
rm -Rf ${CURPATH}_dbg
rm -f /tmp/5.x_debug_build
cp -R ${CURPATH} ${CURPATH}_dbg
cd ${CURPATH}_dbg

### TEMPORARY HACK TO AVOID COMPILING TB (WHICH IS NOT READY YET)
rm -Rf ./plugin/tokudb-backup-plugin

# Avoid previously downloaded boost's from creating problems
rm -Rf /tmp/boost*

if [ $FB -eq 0 ]; then
  # PS,MS,PXC build
  cmake . $CLANG -DCMAKE_BUILD_TYPE=Debug -DWITH_SSL=system -DBUILD_CONFIG=mysql_release -DFEATURE_SET=community -DDEBUG_EXTNAME=OFF -DWITH_EMBEDDED_SERVER=OFF -DENABLE_DOWNLOADS=1 -DDOWNLOAD_BOOST=1 -DWITH_BOOST=/tmp -DENABLED_LOCAL_INFILE=1 -DENABLE_DTRACE=0 -DWITH_PERFSCHEMA_STORAGE_ENGINE=1 -DWITH_ZLIB=system -DWITH_ROCKSDB=${WITH_ROCKSDB} -DWITH_PAM=ON ${ASAN} ${FLAGS} | tee /tmp/5.x_debug_build
else
  # FB build
  cmake . $CLANG -DCMAKE_BUILD_TYPE=Debug -DWITH_SSL=system -DBUILD_CONFIG=mysql_release -DFEATURE_SET=community -DDEBUG_EXTNAME=OFF -DWITH_EMBEDDED_SERVER=OFF -DENABLE_DOWNLOADS=1 -DDOWNLOAD_BOOST=1 -DWITH_BOOST=/tmp -DENABLED_LOCAL_INFILE=1 -DENABLE_DTRACE=0 -DWITH_PERFSCHEMA_STORAGE_ENGINE=1 -DWITH_ZLIB=bundled -DMYSQL_MAINTAINER_MODE=0 ${FLAGS} | tee /tmp/5.x_debug_build
fi
if [ $? -ne 0 ]; then echo "Assert: non-0 exit status detected!"; exit 1; fi
if [ "${ASAN}" != "" -a $MS -eq 1 ]; then
  ASAN_OPTIONS="detect_leaks=0" make -j${MAKE_THREADS} | tee -a /tmp/5.x_debug_build  # Upstream is affected by http://bugs.mysql.com/bug.php?id=80014 (fixed in PS)
  if [ $? -ne 0 ]; then echo "Assert: non-0 exit status detected!"; exit 1; fi
else
  make -j${MAKE_THREADS} | tee -a /tmp/5.x_debug_build
  if [ $? -ne 0 ]; then echo "Assert: non-0 exit status detected!"; exit 1; fi
fi

./scripts/make_binary_distribution | tee -a /tmp/5.x_debug_build  # Note that make_binary_distribution is created on-the-fly during the make compile
if [ $? -ne 0 ]; then echo "Assert: non-0 exit status detected!"; exit 1; fi
TAR_dbg=`ls -1 *.tar.gz | head -n1`
if [[ "${TAR_dbg}" == *".tar.gz"* ]]; then
  DIR_dbg=$(echo "${TAR_dbg}" | sed 's|.tar.gz||')
  TAR_dbg_new=$(echo "${PREFIX}-${TAR_dbg}" | sed 's|.tar.gz|-debug.tar.gz|')
  DIR_dbg_new=$(echo "${TAR_dbg_new}" | sed 's|.tar.gz||')
  if [ "${DIR_dbg}" != "" ]; then rm -Rf ../${DIR_dbg}; fi
  if [ "${DIR_dbg_new}" != "" ]; then rm -Rf ../${DIR_dbg_new}; fi
  if [ "${TAR_dbg_new}" != "" ]; then rm -Rf ../${TAR_dbg_new}; fi
  mv ${TAR_dbg} ../${TAR_dbg_new}
  if [ $? -ne 0 ]; then echo "Assert: non-0 exit status detected!"; exit 1; fi
  cd ..
  tar -xf ${TAR_dbg_new}
  if [ $? -ne 0 ]; then echo "Assert: non-0 exit status detected!"; exit 1; fi
  mv ${DIR_dbg} ${DIR_dbg_new}
  if [ $? -ne 0 ]; then echo "Assert: non-0 exit status detected!"; exit 1; fi
  echo "Done! Now run;"
  echo "mv ../${DIR_dbg_new} /sda"  # The script will end still in $PWD, hence we will need ../ (output only)
  #rm -Rf ${CURPATH}_dbg  # Best not to delete it; this way gdb debugging is better quality as source will be available!
  exit 0
else
  echo "There was some build issue... Have a nice day!"
  exit 1
fi
