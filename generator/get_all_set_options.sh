#!/bin/bash
# Created by Ramesh Sivaraman & Roel Van de Paar, Percona LLC
# This script processes dynamic variables (global + session) and writes generator.sh compatible files for them into /tmp/get_all_set_options

WGET_SKIP=1  # Default: 0. Use 0 when you do not have the HTML files downloaded to /tmp yet (first run). Afterwards, you can set this to 1 to speed up things

SCRIPT_PWD=$(cd `dirname $0` && pwd)
if [ "$1" == "" ]; then
  VERSION_CHECK="5.7"
elif [ "`echo $1 | grep -oe '5\.[67]'`" != "5.6" ] && [ "`echo $1 | grep -oe '5\.[67]'`" != "5.7" ];then
  echo "Invalid option. Valid options are: 5.6 and 5.7, e.g. ./get_all_set_options.sh 5.7"
  echo "If no option is given, 5.7 will be used by default"
  exit 1
else
  VERSION_CHECK=$1
fi

if [ ${WGET_SKIP} -ne 1 ]; then
  rm -Rf /tmp/get_all_set_options
  mkdir /tmp/get_all_set_options
  if [ ! -d /tmp/get_all_set_options ]; then echo "Assert: /tmp/get_all_set_options does not exist after creation!"; exit 1; fi
  cd /tmp/get_all_set_options
  wget http://dev.mysql.com/doc/refman/$VERSION_CHECK/en/server-system-variables.html
  wget http://dev.mysql.com/doc/refman/$VERSION_CHECK/en/innodb-parameters.html
  wget http://dev.mysql.com/doc/refman/$VERSION_CHECK/en/replication-options-binary-log.html
  wget http://dev.mysql.com/doc/refman/$VERSION_CHECK/en/replication-options-slave.html
else
  if [ ! -d /tmp/get_all_set_options ]; then echo "Assert: /tmp/get_all_set_options does not exist (set WGET_SKIP to 0 please)!"; exit 1; fi
  cd /tmp/get_all_set_options
  if [ ! -r server-system-variables.html ]; then echo "Assert: /tmp/server-system-variables.html does not exist (set WGET_SKIP to 0 please)!"; exit 1; fi
  if [ ! -r innodb-parameters.html ]; then echo "Assert: /tmp/innodb-parameters.html does not exist (set WGET_SKIP to 0 please)!"; exit 1; fi
  if [ ! -r replication-options-binary-log.html ]; then echo "Assert: /tmp/replication-options-binary-log.html does not exist (set WGET_SKIP to 0 please)!"; exit 1; fi
  if [ ! -r replication-options-slave.html ]; then echo "Assert: /tmp/replication-options-slave.html does not exist (set WGET_SKIP to 0 please)!"; exit 1; fi
fi

grep '<colgroup><col class="name">' server-system-variables.html | sed 's|<tr>|\n|g;s|<[^>]*>| |g;s|-   Variable  :||g' | grep -vE "^[ \t]*$|Name  Cmd-Line|Reference" | grep -E "Both|Session" | grep 'Yes[ \t]*$' | awk '{print $1}' | sed 's|_|-|g' > session.txt
grep '<colgroup><col class="name">' server-system-variables.html | sed 's|<tr>|\n|g;s|<[^>]*>| |g;s|-   Variable  :||g' | grep -vE "^[ \t]*$|Name  Cmd-Line|Reference" | grep -E "Both|Global" | grep 'Yes[ \t]*$' | awk '{print $1}' | sed 's|_|-|g' > global.txt

grep '<colgroup><col class="name">' innodb-parameters.html | sed 's|<tr>|\n|g;s|<[^>]*>| |g;s|-   Variable  :||g' | grep -vE "^[ \t]*$|Name  Cmd-Line|Reference" | grep -E "Both|Session" | grep 'Yes[ \t]*$' | awk '{print $1}' | sed 's|_|-|g' >> session.txt
grep '<colgroup><col class="name">' innodb-parameters.html | sed 's|<tr>|\n|g;s|<[^>]*>| |g;s|-   Variable  :||g' | grep -vE "^[ \t]*$|Name  Cmd-Line|Reference" | grep -E "Both|Global" | grep 'Yes[ \t]*$' | awk '{print $1}' | sed 's|_|-|g' >> global.txt

grep -o "Command-Line Format.*\-\-[^<]\+" *.html | grep -o "\-\-.*" | sed 's|_|-|g' >> commandlines.txt

# varlist syntax:   Name (1) Cmd-Line (2)  Option File (3)  System Var (4)  Var Scope (5)  Dynamic (6)  (can use awk '{print $x}')
VERSION_CHECK=`echo ${VERSION_CHECK} | sed 's|\.||g'`  # Only change this after retrieving the pages above
sed -i "s/=\[={OFF|ON}\]/[={OFF|ON}]/" commandlines.txt
sed -i "s|\[|@|g;s|\]|@|g" commandlines.txt  # Change [ and ] to @
sort -u -o commandlines.txt commandlines.txt  # Unique self-sort; ensures right order for PRLINE grep

charsets(){
  echo "${PRLINE}" | sed 's|=name|=binary|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=big5|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=dec8|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp850|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=hp8|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=koi8r|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin1|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin2|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=swe7|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ascii|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ujis|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=sjis|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=hebrew|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=tis620|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=euckr|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=koi8u|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=gb2312|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=greek|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1250|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=gbk|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin5|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=armscii8|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp866|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=keybcs2|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=macce|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=macroman|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp852|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin7|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1251|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16le|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1256|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1257|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=geostd8|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp932|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=eucjpms|' >> ${VARFILE}.out
}

collations(){
  echo "${PRLINE}" | sed 's|=name|=big5_chinese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=big5_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=dec8_swedish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=dec8_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp850_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp850_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=hp8_english_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=hp8_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=koi8r_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=koi8r_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin1_german1_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin1_swedish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin1_danish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin1_german2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin1_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin1_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin1_general_cs|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin1_spanish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin2_czech_cs|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin2_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin2_hungarian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin2_croatian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin2_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=swe7_swedish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=swe7_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ascii_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ascii_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ujis_japanese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ujis_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=sjis_japanese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=sjis_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=hebrew_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=hebrew_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=tis620_thai_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=tis620_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=euckr_korean_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=euckr_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=koi8u_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=koi8u_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=gb2312_chinese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=gb2312_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=greek_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=greek_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1250_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1250_czech_cs|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1250_croatian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1250_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1250_polish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=gbk_chinese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=gbk_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin5_turkish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin5_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=armscii8_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=armscii8_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_unicode_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_icelandic_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_latvian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_romanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_slovenian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_polish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_estonian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_spanish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_swedish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_turkish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_czech_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_danish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_lithuanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_slovak_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_spanish2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_roman_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_persian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_esperanto_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_hungarian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_sinhala_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_german2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_croatian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_unicode_520_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_vietnamese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8_general_mysql500_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_unicode_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_icelandic_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_latvian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_romanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_slovenian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_polish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_estonian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_spanish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_swedish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_turkish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_czech_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_danish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_lithuanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_slovak_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_spanish2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_roman_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_persian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_esperanto_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_hungarian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_sinhala_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_german2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_croatian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_unicode_520_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_vietnamese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ucs2_general_mysql500_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp866_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp866_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=keybcs2_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=keybcs2_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=macce_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=macce_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=macroman_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=macroman_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp852_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp852_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin7_estonian_cs|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin7_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin7_general_cs|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=latin7_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_unicode_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_icelandic_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_latvian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_romanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_slovenian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_polish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_estonian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_spanish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_swedish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_turkish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_czech_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_danish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_lithuanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_slovak_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_spanish2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_roman_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_persian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_esperanto_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_hungarian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_sinhala_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_german2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_croatian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_unicode_520_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf8mb4_vietnamese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1251_bulgarian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1251_ukrainian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1251_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1251_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1251_general_cs|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_unicode_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_icelandic_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_latvian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_romanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_slovenian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_polish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_estonian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_spanish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_swedish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_turkish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_czech_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_danish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_lithuanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_slovak_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_spanish2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_roman_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_persian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_esperanto_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_hungarian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_sinhala_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_german2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_croatian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_unicode_520_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16_vietnamese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16le_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf16le_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1256_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1256_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1257_lithuanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1257_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp1257_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_unicode_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_icelandic_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_latvian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_romanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_slovenian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_polish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_estonian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_spanish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_swedish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_turkish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_czech_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_danish_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_lithuanian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_slovak_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_spanish2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_roman_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_persian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_esperanto_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_hungarian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_sinhala_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_german2_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_croatian_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_unicode_520_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=utf32_vietnamese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=binary|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=geostd8_general_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=geostd8_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp932_japanese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=cp932_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=eucjpms_japanese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=eucjpms_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=gb18030_chinese_ci|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=gb18030_bin|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=gb18030_unicode_520_ci|' >> ${VARFILE}.out
}

sqlmode(){
  echo "${PRLINE}" | sed 's|=name|=ALLOW_INVALID_DATES|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ANSI_QUOTES|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ERROR_FOR_DIVISION_BY_ZERO|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=HIGH_NOT_PRECEDENCE|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=IGNORE_SPACE|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_AUTO_CREATE_USER|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_AUTO_VALUE_ON_ZERO|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_BACKSLASH_ESCAPES|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_DIR_IN_CREATE|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_ENGINE_SUBSTITUTION|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_FIELD_OPTIONS|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_KEY_OPTIONS|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_TABLE_OPTIONS|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_UNSIGNED_SUBTRACTION|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_ZERO_DATE|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=NO_ZERO_IN_DATE|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=ONLY_FULL_GROUP_BY|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=PAD_CHAR_TO_FULL_LENGTH|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=PIPES_AS_CONCAT|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=REAL_AS_FLOAT|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=STRICT_ALL_TABLES|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=name|=STRICT_TRANS_TABLES|' >> ${VARFILE}.out
}

optimizerswitch(){
  echo "${PRLINE}" | sed 's|=value|="batched_key_access=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="block_nested_loop=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="condition_fanout_filter=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="derived_merge=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="duplicateweedout=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="engine_condition_pushdown=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="firstmatch=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="index_condition_pushdown=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="index_merge=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="index_merge_intersection=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="index_merge_sort_union=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="index_merge_union=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="loosescan=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="materialization=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="mrr=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="mrr_cost_based=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="semijoin=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="subquery_materialization_cost_based=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="use_index_extensions=on"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="batched_key_access=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="block_nested_loop=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="coffditioff_fanout_filter=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="derived_merge=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="duplicateweedout=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="engine_coffditioff_pushdown=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="firstmatch=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="index_coffditioff_pushdown=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="index_merge=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="index_merge_intersectioff=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="index_merge_sort_unioff=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="index_merge_unioff=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="loosescan=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="materializatioff=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="mrr=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="mrr_cost_based=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="semijoin=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="subquery_materializatioff_cost_based=off"|' >> ${VARFILE}.out
  echo "${PRLINE}" | sed 's|=value|="use_index_extensioffs=off"|' >> ${VARFILE}.out
}

parse_set_vars(){
  rm ${VARFILE}.out 2>/dev/null
  for line in $(cat ${VARFILE}); do
    HANDLED=0
    PRLINE=$(grep "^\-\-$line" ./commandlines.txt | sed "s|[ \t]\+||" | head -n1)
    if [ "${PRLINE}" != "" ]; then  # ================= STAGE 0: Line is present in "Command-Line Format" capture file; use this to handle setting variables
      if [[ "${PRLINE}" == *"=dir-name"* ]] || [[ "${PRLINE}" == *"=path"* ]] || [[ "${PRLINE}" == *"=directory"* ]]; then
        # These variables (--datadir, --character-sets-dir, --basedir etc.) are skipped as they do not make sense to modify, and they are unlikely to be dynamic;
        # Note that this ifthen may not even be hit for all cases present in commandlines.txt. For example, --datadir is not dynamic and so it will not be in global/session txt
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"debug@=debug-options@"* ]] || [[ "${PRLINE}" == *"log-output=name"* ]] || [[ "${PRLINE}" == *"slow-query-log-file=file-name"* ]] || [[ "${PRLINE}" == *"innodb-buffer-pool-filename=file"* ]] || [[ "${PRLINE}" == *"general-log-file=file-name"* ]] || [[ "${PRLINE}" == *"keyring-file-data=file-name"* ]] || [[ "${PRLINE}" == *"init-connect=name"* ]]; then
        # The variables are not handled as they do not make much sense to modify/test
        HANDLED=1
      fi
      if ! [[ "${PRLINE}" == *"="* ]]; then  # Variable without any options, for example --general-log. These need to get =0 and =1 because:
        # echo "${LINE}" >> ${VARFILE}.out  # SET does not work like --option eg. --innodb_file_per_table works, SET @@GLOBAL.innodb_file_per_table doesn't
        echo "${PRLINE}=0" >> ${VARFILE}.out
        echo "${PRLINE}=1" >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"@={OFF|ON}@"* ]]; then
        PRLINE=$(echo ${PRLINE} | sed 's/@={OFF|ON}@//')
        echo "${PRLINE}=0" >> ${VARFILE}.out
        echo "${PRLINE}=1" >> ${VARFILE}.out
        HANDLED=1
      fi
      if [ ${HANDLED} -eq 0 ]; then
        if [[ "${PRLINE}" == *"={OFF|ON}"* ]]; then
          PRLINE=$(echo ${PRLINE} | sed 's/={OFF|ON}//')
          echo "${PRLINE}=0" >> ${VARFILE}.out
          echo "${PRLINE}=1" >> ${VARFILE}.out
          HANDLED=1
        fi
      fi
      if [[ "${PRLINE}" == *"@={0|1}@"* ]]; then
        PRLINE=$(echo ${PRLINE} | sed 's/@={0|1}@//')
        echo "${PRLINE}=0" >> ${VARFILE}.out
        echo "${PRLINE}=1" >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"@=#@"* ]]; then
        echo "${PRLINE}" | sed 's|@=#@|=DUMMY|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [ ${HANDLED} -eq 0 ]; then
        if [[ "${PRLINE}" == *"=#"* ]]; then
          echo "${PRLINE}" | sed 's|=#|=DUMMY|' >> ${VARFILE}.out
          HANDLED=1
        fi
      fi
      if [[ "${PRLINE}" == *"=engine@,engine@..."* ]]; then
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=MyISAM|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=InnoDB|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=CSV|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=MRG_MYISAM|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=TokuDB|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=RocksDB|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=BLACKHOLE|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=PERFORMANCE_SCHEMA|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=MEMORY|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=FEDERATED|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=CSV,FEDERATED|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=engine@,engine@...|=CSV,MRG_MYISAM|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"default-storage-engine=name"* ]] || [[ "${PRLINE}" == *"default-tmp-storage-engine=name"* ]] ; then
        echo "${PRLINE}" | sed 's|=name|=MyISAM|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=InnoDB|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=CSV|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=MRG_MYISAM|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=TokuDB|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=RocksDB|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=BLACKHOLE|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=PERFORMANCE_SCHEMA|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=MEMORY|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=FEDERATED|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=CSV,FEDERATED|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=CSV,MRG_MYISAM|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"default-authentication-plugin=plugin-name"* ]]; then
        echo "${PRLINE}" | sed 's|=plugin-name|=mysql_native_password|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=plugin-name|=sha256_password|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"event-scheduler@=value@"* ]]; then
        echo "${PRLINE}" | sed 's|@=value@|=ON|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|@=value@|=OFF|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|@=value@|=DISABLED|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"character-set-filesystem=name"* ]]; then
        charsets
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"innodb-ft-user-stopword-table=db-name/table-name"* ]] || [[ "${PRLINE}" == *"innodb-ft-stopword-table=db-name/table-name"* ]] || [[ "${PRLINE}" == *"innodb-ft-server-stopword-table"* ]]; then
        echo "${PRLINE}" | sed 's|=db-name/table-name|=test/t1|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=db-name/table-name|=test/t2|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=db-name/table-name|=test/t3|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"innodb-monitor-reset-all"* ]] || [[ "${PRLINE}" == *"innodb-monitor-disable"* ]] || [[ "${PRLINE}" == *"innodb-monitor-enable"* ]]; then
        echo "${PRLINE}" | sed 's/=@counter|module|pattern|all@/=counter/' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's/=@counter|module|pattern|all@/=module/' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's/=@counter|module|pattern|all@/=pattern/' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's/=@counter|module|pattern|all@/=all/' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"sql-mode=name"* ]]; then
        sqlmode
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"innodb-stats-method=name"* ]] || [[ "${PRLINE}" == *"myisam-stats-method=name"* ]]; then
        echo "${PRLINE}" | sed 's|=name|=nulls_equal|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=nulls_unequal|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=nulls_ignored|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"optimizer-switch=value"* ]]; then
        optimizerswitch
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"=N"* ]]; then
        echo "${PRLINE}" | sed 's|=N|=DUMMY|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"session-track-gtids=@value@"* ]]; then
        echo "${PRLINE}" | sed 's|=@value@|=OFF|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=@value@|=OWN_GTID|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=@value@|=ALL_GTIDS|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"transaction-write-set-extraction=@value@"* ]]; then
        echo "${PRLINE}" | sed 's|=@value@|=OFF|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=@value@|=MURMUR32|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"delay-key-write@=name@"* ]]; then
	echo "${PRLINE}" | sed 's|@=name@|=ON|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|@=name@|=OFF|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|@=name@|=ALL|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"ft-boolean-syntax=name"* ]]; then
        echo "${PRLINE}" | sed "s/=name/='+ -><()~*:\"\"&|'/" >> ${VARFILE}.out
        echo "${PRLINE}" | sed "s/=name/=' +-><()~*:\"\"&|'/" >> ${VARFILE}.out
        echo "${PRLINE}" | sed "s/=name/=' *:\"\"&|+-><()~'/" >> ${VARFILE}.out
        echo "${PRLINE}" | sed "s/=name/=' ()~*:\"\"&|+-><'/" >> ${VARFILE}.out
        echo "${PRLINE}" | sed "s/=name/='( ><)\"~*:\"&|+-'/" >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"offline-mode=val"* ]]; then
        echo "${PRLINE}" | sed 's|=val|=0|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=val|=1|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"max-points-in-geometry=integer"* ]]; then
        echo "${PRLINE}" | sed 's|=integer|=DUMMY|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"log-syslog-facility=value"* ]]; then
        echo "${PRLINE}" | sed 's|=value|=deamon|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=value|=syslog|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=value|=syslogd|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=value|=echo|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=value|=mysqld|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"log-syslog-tag=value"* ]]; then
        echo "${PRLINE}" | sed "s|=value|='abc'|" >> ${VARFILE}.out
        echo "${PRLINE}" | sed "s|=value|='123'|" >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"master-verify-checksum=name"* ]]; then
        echo "${PRLINE}" | sed 's|=name|=0|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=name|=1|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"binlog-checksum=type"* ]]; then
        echo "${PRLINE}" | sed 's|=type|=NONE|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=type|=CRC32|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"binlog-direct-non-transactional-updates@=value@"* ]]; then
        echo "${PRLINE}" | sed 's|@=value@|=0|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|@=value@|=1|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"binlog-error-action@=value@"* ]] || [[ "${PRLINE}" == *"binlogging-impossible-mode@=value@"* ]]; then
        echo "${PRLINE}" | sed 's|@=value@|=IGNORE_ERROR|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|@=value@|=ABORT_SERVER|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"binlog-format=format"* ]]; then
        echo "${PRLINE}" | sed 's|=format|=ROW|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=format|=STATEMENT|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=format|=MIXED|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"binlog-row-image=image-type"* ]]; then
        echo "${PRLINE}" | sed 's|=image-type|=full|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=image-type|=minimal|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=image-type|=noblob|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"master-info-repository=FILE|TABLE"* ]] || [[ "${PRLINE}" == *"relay-log-info-repository=FILE|TABLE"* ]]; then
        echo "${PRLINE}" | sed 's/=FILE|TABLE/=FILE/' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's/=FILE|TABLE/=TABLE/' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"rpl-stop-slave-timeout=seconds"* ]]; then
        echo "${PRLINE}" | sed 's|=seconds|=DUMMY|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"init-slave=name"* ]]; then
        echo "${PRLINE}" | sed "s|=name|='SELECT 1'|" >> ${VARFILE}.out  # This can likely be improved and made recursive by using something like SQLDUMMY and replacing that with random SQL by generator.sh (via for example grabbing an already-generated line if an output file is already present)
        echo "${PRLINE}" | sed "s|=name|='CREATE TABLE t1 (c1 INT)'|" >> ${VARFILE}.out
        echo "${PRLINE}" | sed "s|=name|='DROP TABLE t1'|" >> ${VARFILE}.out
        echo "${PRLINE}" | sed "s|=name|='FLUSH TABLES'|" >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"slave-exec-mode=mode"* ]]; then
        echo "${PRLINE}" | sed 's|=mode|=IDEMPOTENT|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=mode|=STRICT|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"slave-parallel-type=type"* ]]; then
        echo "${PRLINE}" | sed 's|=type|=DATABASE|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=type|=LOGICAL_CLOCK|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"slave-preserve-commit-order=value"* ]]; then
        echo "${PRLINE}" | sed 's|=value|=0|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=value|=1|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"slave-rows-search-algorithms=list"* ]]; then
        echo "${PRLINE}" | sed 's|=list|=TABLE_SCAN,INDEX_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=TABLE_SCAN,INDEX_SCAN,HASH_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=INDEX_SCAN,TABLE_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=INDEX_SCAN,TABLE_SCAN,HASH_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=TABLE_SCAN,HASH_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=TABLE_SCAN,HASH_SCAN,INDEX_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=HASH_SCAN,TABLE_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=HASH_SCAN,TABLE_SCAN,INDEX_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=INDEX_SCAN,HASH_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=INDEX_SCAN,HASH_SCAN,TABLE_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=HASH_SCAN,INDEX_SCAN|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=list|=HASH_SCAN,INDEX_SCAN,TABLE_SCAN|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${PRLINE}" == *"slave-sql-verify-checksum=value"* ]]; then
        echo "${PRLINE}" | sed 's|=value|=0|' >> ${VARFILE}.out
        echo "${PRLINE}" | sed 's|=value|=1|' >> ${VARFILE}.out
        HANDLED=1
      fi
      if [ ${HANDLED} -eq 0 ]; then
        echo "Not handled yet (stage #0): $PRLINE"
      fi
    else  # ================= STAGE 1: Line is not present in "Command-Line Format" capture file; handle some 1-by-1
      LINE=$(echo ${line} | sed "s|[ \t]\+||")
      if [[ "${LINE}" == "ndb"* ]]; then
        # No need to include/handle NDB related variables
        HANDLED=1
      fi
      if [[ "${LINE}" == *"auto-increment-increment"* ]]; then
        echo "auto-increment-increment=DUMMY" >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${LINE}" == *"auto-increment-offset"* ]]; then
        echo "auto-increment-offset=DUMMY" >> ${VARFILE}.out
        HANDLED=1
      fi
      if [[ "${LINE}" == *"character-set-"* ]]; then
        PRLINE="${LINE}=name"
        charsets
        HANDLED=1
      fi
      if [[ "${LINE}" == *"collation-"* ]]; then
        PRLINE="${LINE}=name"
        collations 
        HANDLED=1
      fi
      if [[ "${LINE}" == *"tx-isolation"* ]]; then
        echo 'tx-isolation="READ-UNCOMMITTED"' >> ${VARFILE}.out
        echo 'tx-isolation="READ-COMMITTED"' >> ${VARFILE}.out
        echo 'tx-isolation="REPEATABLE-READ"' >> ${VARFILE}.out
        echo 'tx-isolation="SERIALIZABLE"' >> ${VARFILE}.out
        HANDLED=1
      fi
      #  ================= STAGE 2: Look through HTML to see if a default value is present
      TYPE=
      TYPE=$(grep "${LINE}.*Permitted Values" *.html | head -n1 | sed 's|<td>|\n|;s|<[^>]\+>| |g;s|[ \t]\+| |g' | grep -o "Type.*Default" | sed 's|Type||;s|Default||;s| ||g' | head -n1)
      if [ "${TYPE}" == "" ]; then
        TYPE=$(grep "$(echo ${LINE}|sed 's|\-|_|g').*Permitted Values" *.html | head -n1 | sed 's|<td>|\n|;s|<[^>]\+>| |g;s|[ \t]\+| |g' | grep -o "Type.*Default" | sed 's|Type||;s|Default||;s| ||g' | head -n1)
      fi
      if [ "${TYPE}" == "boolean" ]; then
        echo "${LINE}=0" >> ${VARFILE}.out
        echo "${LINE}=1" >> ${VARFILE}.out
        HANDLED=1
      elif [ "${TYPE}" == "integer" ]; then
        echo "${LINE}=DUMMY" >> ${VARFILE}.out
        HANDLED=1
      elif [ "${TYPE}" == "numeric" ]; then
        echo "${LINE}=DUMMY" >> ${VARFILE}.out
        HANDLED=1
      fi
      if [ ${HANDLED} -eq 0 ]; then
        echo "Not handled yet (stage #1): $LINE"  # This says 'stage #1' as that is where the options need to be added above, i.e. not in THIS stage stage #2. But the check can only be done here once stage #2 is complete.
      fi
    fi
  done
}

VARFILE=session.txt; parse_set_vars
VARFILE=global.txt;  parse_set_vars

# Remove preceding --
sed -i "s|^\-\-||" session.txt.out
sed -i "s|^\-\-||" global.txt.out
:
# Changing variable names '-' into '_' which works by default
sed -i 'h;s|-|_|g;s|\([^=]\+\).*|\1|;x;s|[^=]\+||;x;G;s|\n||' session.txt.out
sed -i 'h;s|-|_|g;s|\([^=]\+\).*|\1|;x;s|[^=]\+||;x;G;s|\n||' global.txt.out

# Fixes/workarounds for buggy variables (errors in manual - log DOC bugs later)
sed -i "s|innodb_print_all_deadlocks=DUMMY|innodb_print_all_deadlocks=0\ninnodb_print_all_deadlocks=1|" global.txt.out  # innodb_print_all_deadlocks is global variable only
      
# Final rename to version
rm session.txt global.txt 2>/dev/null
mv session.txt.out session_${VERSION_CHECK}.txt
mv global.txt.out global_${VERSION_CHECK}.txt

echo ""
echo "Done! Results are in; /tmp/get_all_set_options/global_${VERSION_CHECK}.txt and /tmp/get_all_set_options/session_${VERSION_CHECK}.txt"
echo "Please copy these files to the generator directory, overwriting any file already there:"
echo "cp /tmp/get_all_set_options/global_${VERSION_CHECK}.txt /tmp/get_all_set_options/session_${VERSION_CHECK}.txt ."

#  if [ $(grep -c $line $SCRIPT_PWD/pquery/mysqld_options_ms_${VERSION_CHECK}.txt ) -ne 0 ];then
#    if [ $(grep -c $line $SCRIPT_PWD/pquery/mysqld_options_ms_${VERSION_CHECK}.txt ) -eq 2 ];then
#      grep $line $SCRIPT_PWD/pquery/mysqld_options_ms_${VERSION_CHECK}.txt | sed 's|--||g;s|-|_|g' >> setvar_$VERSION_CHECK.txt
#    else
#      TEST_VAL=`grep $line $SCRIPT_PWD/pquery/mysqld_options_ms_${VERSION_CHECK}.txt | cut -d"=" -f2 | head -n1`
#      if [ "$TEST_VAL" -eq "$TEST_VAL" ] 2>/dev/null; then
#        echo "$line=DUMMY" | sed 's|-|_|g' >> setvar_$VERSION_CHECK.txt
#      else
#        grep $line $SCRIPT_PWD/pquery/mysqld_options_ms_${VERSION_CHECK}.txt | sed 's|--||g;s|-|_|g'  >> setvar_$VERSION_CHECK.txt
#      fi
#    fi
#  else
#    echo $line >> missing_setvar_$VERSION_CHECK.txt
#  fi
#done < varlist.txt

