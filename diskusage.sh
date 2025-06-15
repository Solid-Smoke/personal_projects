#!/bin/bash

# diskusage v1.0.1

logfile="$HOME/.diskusage.txt"

df -h -BM /

if [ ! -f "$logfile" ]; then
  (echo -ne "Timestamp\t    " && df -h -BM /) | head -n 1 > "$logfile"
fi

echo "$(date +%F\ %T) $(df -h -BM / | tail -n 1)" >> "$logfile"
echo "See log with: cat $logfile"
