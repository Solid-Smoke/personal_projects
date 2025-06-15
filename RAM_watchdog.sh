#!/bin/bash
# Run in backgroud: nohup ./ram_watchdog.sh [OPTIONS] &

# Defaults
PROGRAM_NAME=""
SLEEP_TIME=5
TIMEOUT=10
LIMIT_KB=0
LIMIT_G_SET=0
LIMIT_M_SET=0
ALL_USERS=false
SIGKILL=false

HELPMESSAGE="Usage: $0 [OPTIONS]\n
            Options:\n
                --name|-n <program> Program name to monitor. 
                                    Default monitors all proccesses.\n
                --limitG|-lg <GB> || --limitM|-lm <MB>  Limit of RAM usage allowed in either GB or MB. 
                                                        Default is 8 GB.\n
                --interval|-i <seconds> Time between monitor cycles. 
                                        Default is 5s.\n
                --timeout|-t <seconds> Time to wait before giving up on SIGTERM. 
                                        Default is 10s.\n
                --allusers|-au Monitor for the proccesses of all users. 
                                Default is false.\n
                --sigkill|-sk Send a SIGKILL if SIGTERM fail to end the process. 
                                Default is false.\n"

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --name|-n) PROGRAM_NAME="$2"; shift 2 ;;
        --limitG|-lg) LIMIT_KB=$(( $2 * 1024 * 1024 )); LIMIT_G_SET=1; shift 2 ;;
        --limitM|-lm) LIMIT_KB=$(( $2 * 1024 )); LIMIT_M_SET=1; shift 2 ;;
        --interval|-i) SLEEP_TIME="$2"; shift 2 ;;
        --timeout|-t) TIMEOUT="$2"; shift 2 ;;
        --allusers|-au) ALL_USERS=true; shift 2 ;; 
        --sigkill|-sk) SIGKILL=true; shift 2;;
        --help|-h)
            echo -e $HELPMESSAGE; exit 0;;
        *)
            echo "Unknown parameter: $1"
            echo "Use --help|-h for usage instructions."
            exit 1
            ;;
    esac
done

# Enforce mutual exclusivity in LIMIT
if [[ "$LIMIT_G_SET" -eq 1 && "$LIMIT_M_SET" -eq 1 ]]; then
    echo "Use only --limitG|-lg or --limitM|-lm, not both."
    exit 1
fi

# Default to 8GB if neither is set
if [[ "$LIMIT_KB" -eq 0 ]]; then
    LIMIT_KB=$((8 * 1024 * 1024))
fi

CURRENT_UID=$(id -u) # whoami
MY_PID=$$  #whothisproc

STARTMESSAGE="RAM watchdog v0.1.6\n
              Limit the amount of RAM a process can take.\n
                Monitoring: ${PROGRAM_NAME:-all processes}\n
                RAM Limit: $((LIMIT_KB / 1024)) MB\n
                Interval: $SLEEP_TIME seconds\n
                Timeout: $TIMEOUT seconds\n
                Monitoring all users processes? $ALL_USERS\n
                Use SIGKILL if SIGTERM fails? $SIGKILL\n"

echo -e $STARTMESSAGE

while true; do
  if [[ -n "$PROGRAM_NAME" ]]; then
    pids=$(pgrep -f "$PROGRAM_NAME") # specified proc name
  else
    pids=$(ls /proc | grep '^[0-9]\+$') # any proc
  fi

  # Don't commit suicide
  for pid in $pids; do
    if [[ "$pid" == "$MY_PID" ]]; then
      continue
    fi
    
    if ! $ALL_USERS; then
        # Only target current user iniciated procs
        proc_uid=$(stat -c %u /proc/$pid 2>/dev/null)
          if [[ "$proc_uid" != "$CURRENT_UID" ]]; then
            continue
          fi
    fi

    # if readable check if over LIMIT and SIGTERM
    if [[ -r /proc/$pid/status && -r /proc/$pid/cmdline ]]; then
      mem_kb=$(grep VmRSS /proc/$pid/status 2>/dev/null | awk '{print $2}')
      if [[ -n "$mem_kb" && "$mem_kb" -gt "$LIMIT_KB" ]]; then
        cmdline=$(tr -d '\0' < /proc/$pid/cmdline)
        echo "SIGTERM to process $pid ($cmdline) using ${mem_kb}KB"
        kill $pid
        
        # Wait
        for ((i=0; i<TIMEOUT; i++)); do
          if ! kill -0 $pid 2>/dev/null; then
            date= date +%H:%M:%S-%d/%m
            echo -e "Process $pid terminated gracefully at $date, after SIGTERM.\n"
            break
          fi
          sleep 1
        done
        
        # Force kill if enabled
        if $SIGKILL; then
            kill -9 $pid
            date= date +%H:%M:%S-%d/%m
            echo -e "Process $pid terminated forcefully at $date, after SIGKILL.\n"
        fi

        # Give up
        if kill -0 $pid 2>/dev/null; then
          echo -e "Process $pid did not terminate after $TIMEOUT seconds. Giving up.\n"
        fi
      fi
    fi
  done

  sleep "$SLEEP_TIME"
done
