#!/bin/bash
# Created by Alexander aka BioDranik <me@alex.bio> in Minsk, Belarus

set -eu

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path_to_directory_where_to_test_read_and_write_speed>"
  exit 1
fi

# Keep '.' as the decimal separator for `time` and awk regardless of locale.
export LC_NUMERIC=C

SD_DIR=$1
FILENAME="$SD_DIR/file_speed_test.deleteme"
SIZE=1000 # in MB

if [ ! -d "$SD_DIR" ]; then
  echo "Error: '$SD_DIR' is not a directory." >&2
  exit 1
fi
if [ ! -w "$SD_DIR" ]; then
  echo "Error: '$SD_DIR' is not writable." >&2
  exit 1
fi

# Always delete the created file, even on Ctrl-C or termination.
trap 'rm -f -- "$FILENAME"' EXIT
trap 'exit 130' INT TERM

DoWrite() {
  if [[ "$OSTYPE" == darwin* ]]; then
    mkfile "${SIZE}m" "$FILENAME"
    sync
  else
    # conv=fdatasync flushes our file to the device before dd exits, so the
    # timing reflects the card and not the page cache (works on FAT/exFAT too).
    dd if=/dev/zero of="$FILENAME" bs=1M count="$SIZE" conv=fdatasync
  fi
}

DoRead() {
  cat -- "$FILENAME"
}

# Times the command given as separate arguments and prints elapsed real seconds
# (e.g. "12.345"). The command's own output is discarded.
RunTimeInSeconds() {
  local TIMEFORMAT=%R
  { time "$@" >/dev/null 2>&1; } 2>&1
}

# Converts elapsed seconds ($1) into a MB/sec figure, or "n/a" when the timing
# is missing, non-numeric, or zero (which would divide by zero).
SecondsToSpeed() {
  awk -v size="$SIZE" -v seconds="$1" \
    'BEGIN { if (seconds ~ /^[0-9]+(\.[0-9]+)?$/ && seconds > 0) printf "%.2f\n", size / seconds; else print "n/a" }'
}

ClearFileCache() {
  if ! sudo -n true 2>/dev/null; then
    echo "Administrator password is required to clear file cache and get correct read test results."
  fi
  if [[ "$OSTYPE" == darwin* ]]; then
    sudo purge
  else
    sync && sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
  fi
}

WriteFile() {
  echo "Writing ${SIZE}MB file $FILENAME..."
  local seconds
  seconds=$(RunTimeInSeconds DoWrite) || true
  # Verify the whole file was written; a short file (e.g. the card filling up
  # mid-write) would otherwise report an inflated speed against SIZE.
  local expected=$((SIZE * 1024 * 1024))
  local actual
  actual=$(wc -c < "$FILENAME" 2>/dev/null) || actual=0
  if (( actual < expected )); then
    echo "Error writing file $FILENAME (wrote $actual of $expected bytes)." >&2
    return 1
  fi
  echo "Average sequential write speed: $(SecondsToSpeed "$seconds")MB/sec."
}

ReadFile() {
  local seconds
  seconds=$(RunTimeInSeconds DoRead) || true
  echo "Average sequential read speed: $(SecondsToSpeed "$seconds")MB/sec."
}

WriteFile
if ! ClearFileCache; then
  echo "Warning: failed to clear file cache; read speed may be inaccurate." >&2
fi
ReadFile
