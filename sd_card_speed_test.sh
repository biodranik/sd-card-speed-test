#!/bin/bash
# Created by Alexander aka BioDranik <me@alex.bio> in Minsk, Belarus

set -eu

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path_to_directory_where_to_test_read_and_write_speed>"
  exit 1
fi

SD_DIR=$1
FILENAME="$SD_DIR/file_speed_test.deleteme"
SIZE=1000 # in MB

if [[ "$OSTYPE" == "darwin"* ]]; then
  WRITE_FILE_COMMAND="mkfile ${SIZE}m $FILENAME"
  CLEAR_CACHE_COMMAND="purge"
else
  WRITE_FILE_COMMAND="dd if=/dev/zero of=$FILENAME bs=1M count=$SIZE oflag=direct"
  CLEAR_CACHE_COMMAND='sh -c echo 3 > /proc/sys/vm/drop_caches'
fi
READ_FILE_COMMAND="cat $FILENAME > /dev/null"

RunTimeInSeconds() {
  local TIMEFORMAT=%R
  RES=`{ time $@ >/dev/null 2>&1; } 2>&1`
  echo $RES
}

ClearFileCache() {
  if sudo -n false 2>/dev/null; then
    echo "Administrator password is required to clear file cache and get correct read test results."
  fi
  sudo $CLEAR_CACHE_COMMAND
}

WriteFile() {
  echo "Writing ${SIZE}MB file $FILENAME..."
  local WRITE_SECONDS=`RunTimeInSeconds $WRITE_FILE_COMMAND`
  if [ -f "$FILENAME" ]; then
    local WRITE_SPEED=$( echo "scale=2; $SIZE/$WRITE_SECONDS" | bc -l)
    echo "Average sequential write speed: ${WRITE_SPEED}MB/sec."
  else
    echo "Error writing file $FILENAME"
    false
  fi
}

ReadFile() {
  local READ_SECONDS=`RunTimeInSeconds $READ_FILE_COMMAND`
  local READ_SPEED=$( echo "scale=2; $SIZE/$READ_SECONDS" | bc -l)
  echo "Average sequential read speed: ${READ_SPEED}MB/sec."
}

WriteFile
# Always delete created file on exit.
trap "rm $FILENAME" 0
ClearFileCache
ReadFile
