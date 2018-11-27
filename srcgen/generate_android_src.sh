#!/bin/bash
# Copyright (C) 2018 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [[ -z "${ANDROID_BUILD_TOP}" ]]; then
    echo "Missing environment variables. Did you run build/envsetup.sh and lunch?" >&2
    exit 1
fi

CLASSPATH=${ANDROID_HOST_OUT}/framework/currysrc.jar
PROJECT_DIR=${ANDROID_BUILD_TOP}/external/libphonenumber

cd ${ANDROID_BUILD_TOP}
make -j15 currysrc

UNSUPPORTED_APP_USAGE_FILE=${PROJECT_DIR}/srcgen/unsupported-app-usage.json

function do_transform() {
  local SRC_IN_DIR=$1
  local SRC_OUT_DIR=$2

  if [ ! -d $SRC_OUT_DIR ]; then
    echo ${SRC_OUT_DIR} does not exist >&2
    exit 1
  fi
  rm -rf ${SRC_OUT_DIR}
  mkdir -p ${SRC_OUT_DIR}

  java -cp ${CLASSPATH} com.google.currysrc.aosp.RepackagingTransform \
       --source-dir ${SRC_IN_DIR} \
       --target-dir ${SRC_OUT_DIR} \
       --package-transformation "com.google:com.android" \
       --tab-size 2 \
       --unsupported-app-usage-file ${UNSUPPORTED_APP_USAGE_FILE} \

}

REPACKAGED_DIR=${PROJECT_DIR}/repackaged
for i in libphonenumber geocoder internal/prefixmapper
do
  for s in src
  do
    IN=${PROJECT_DIR}/$i/$s
    if [ -d $IN ]; then
      OUT=${REPACKAGED_DIR}/$i/$s
      do_transform ${IN} ${OUT}

      # Copy any resources
      echo Copying resources from ${IN} to ${OUT}
      RESOURCES=$(find ${IN} -type f | egrep -v '(\.java|\/package\.html)' || true)
      for RESOURCE in ${RESOURCES}; do
        SOURCE_DIR=$(dirname ${RESOURCE})
        RELATIVE_SOURCE_DIR=$(echo ${SOURCE_DIR} | sed "s,${IN}/,,")
        RELATIVE_DEST_DIR=$(echo ${RELATIVE_SOURCE_DIR} | sed 's,com/google,com/android,')
        DEST_DIR=${OUT}/${RELATIVE_DEST_DIR}
        mkdir -p ${DEST_DIR}
        cp $RESOURCE ${DEST_DIR}
      done
    fi
  done
done
