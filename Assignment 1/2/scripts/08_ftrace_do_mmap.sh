#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - ftrace function graph and memory events
# The program runs without root privileges.
# Main ftrace settings are restored on exit.

cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

TRACE=/sys/kernel/tracing
OUT=logs/ftrace
mkdir -p "$OUT"

GRAPH="$OUT/08_do_mmap_ftrace.trace"
BEFORE="$OUT/08_previous_main_trace.txt"

EVENTS=(
  syscalls/sys_enter_mmap
  syscalls/sys_exit_mmap
  kmem/kmalloc
  kmem/kmem_cache_alloc
  kmem/mm_page_alloc
  kmem/rss_stat
)

write_trace() {
  printf '%s\n' "$2" | sudo tee "$TRACE/$1" >/dev/null
}

clear_trace() {
  printf '\n' | sudo tee "$TRACE/$1" >/dev/null
}

sudo -v

# Protect previous results.
[[ -x src/program ]] || {
  echo "ERROR: src/program is missing."
  exit 1
}

[[ ! -e "$GRAPH" && ! -e "$BEFORE" ]] || {
  echo "ERROR: Previous output files exist."
  echo "Preserve them before repeating this experiment."
  exit 1
}

# Inspect the shared main ftrace configuration.
ORIGINAL_TRACING_ON=$(sudo cat "$TRACE/tracing_on")
CURRENT_TRACER=$(sudo cat "$TRACE/current_tracer")
CURRENT_EVENTS=$(sudo cat "$TRACE/set_event")
CURRENT_GRAPH_FILTER=$(sudo cat "$TRACE/set_graph_function")
CURRENT_FUNCTION_FILTER=$(sudo cat "$TRACE/set_ftrace_filter")
CURRENT_FTRACE_PID=$(sudo cat "$TRACE/set_ftrace_pid")
CURRENT_EVENT_PID=$(sudo cat "$TRACE/set_event_pid")

if [[ "$CURRENT_TRACER" != nop ||
      -n "$CURRENT_EVENTS" ||
      "$CURRENT_GRAPH_FILTER" != '#### all functions enabled ####' ||
      "$CURRENT_FUNCTION_FILTER" != '#### all functions enabled ####' ||
      "$CURRENT_FTRACE_PID" != 'no pid' ||
      -n "$CURRENT_EVENT_PID" ]]; then
  echo "ERROR: Main ftrace has custom or active settings."
  echo "Refusing to overwrite another tracing configuration."
  exit 1
fi

for event in "${EVENTS[@]}"; do
  [[ -f "$TRACE/events/$event/enable" ]] || {
    echo "ERROR: Missing tracepoint: $event"
    exit 1
  }
done

armed=0
child_pid=''

cleanup() {
  rc=$?
  trap - EXIT INT TERM

  if [[ -n "$child_pid" ]]; then
    kill -CONT "$child_pid" 2>/dev/null || true
    kill "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi

  if (( armed )); then
    write_trace tracing_on 0 || true

    for event in "${EVENTS[@]}"; do
      write_trace "events/$event/enable" 0 || true
    done

    clear_trace set_event_pid || true
    clear_trace set_ftrace_pid || true
    clear_trace set_graph_function || true
    write_trace current_tracer nop || true
    write_trace tracing_on "$ORIGINAL_TRACING_ON" || true

    echo "Main ftrace settings restored."
  fi

  exit "$rc"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "=== Lab 2: ftrace do_mmap ==="
echo "Kernel: $(uname -r)"
echo "Date: $(date -Is)"

# Save the pre-existing trace buffer before clearing it.
sudo cat "$TRACE/trace" > "$BEFORE"
echo "Previous trace snapshot saved."

armed=1

# Configure the function graph while tracing is stopped.
write_trace tracing_on 0
clear_trace trace
write_trace set_graph_function do_mmap
write_trace current_tracer function_graph

for event in "${EVENTS[@]}"; do
  write_trace "events/$event/enable" 1
done

echo "Function graph and memory events configured."

# Start a normal-user process, paused before exec.
bash -c 'kill -STOP "$BASHPID"; exec "$1"' \
  _ "$PWD/src/program" \
  > "$OUT/08_program.stdout" \
  2> "$OUT/08_program.stderr" &

child_pid=$!

ready=0
for (( i=0; i<100; i++ )); do
  state=$(ps -o stat= -p "$child_pid" 2>/dev/null || true)

  if [[ "$state" == *T* ]]; then
    ready=1
    break
  fi

  sleep 0.02
done

if (( ! ready )); then
  echo "ERROR: Program did not pause before tracing."
  exit 1
fi

# Restrict tracing to the selected process.
write_trace set_ftrace_pid "$child_pid"
write_trace set_event_pid "$child_pid"

echo "Tracing PID: $child_pid"

write_trace tracing_on 1
kill -CONT "$child_pid"

if wait "$child_pid"; then
  program_rc=0
else
  program_rc=$?
fi

child_pid=''

# Stop and export the trace.
write_trace tracing_on 0
sudo cat "$TRACE/trace" > "$GRAPH"

echo
echo "Program exit code: $program_rc"
echo "Trace saved: $GRAPH"

echo "do_mmap graph matches:"
grep -c 'do_mmap()' "$GRAPH" || true

echo
echo "Program output:"
cat "$OUT/08_program.stdout"

echo
echo "Trace preview:"
sed -n '1,28p' "$GRAPH"

(( program_rc == 0 )) || exit "$program_rc"
