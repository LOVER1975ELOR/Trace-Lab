import re
import subprocess
from collections import Counter

trace = "logs/lttng/matrix4-v2-gui/kernel"
workers = [8747, 8748, 8749, 8750]

switch_in = Counter()
switch_out = Counter()
states = {tid: Counter() for tid in workers}
waking = Counter()
wakeup = Counter()
wakeup_new = Counter()

def field(line, name):
    match = re.search(
        rf"\b{re.escape(name)}\s*=\s*(-?\d+)",
        line
    )
    return int(match.group(1)) if match else None

proc = subprocess.Popen(
    ["babeltrace", trace],
    stdout=subprocess.PIPE,
    text=True
)

for line in proc.stdout:
    if " sched_switch:" in line:
        prev_tid = field(line, "prev_tid")
        next_tid = field(line, "next_tid")

        if next_tid in workers:
            switch_in[next_tid] += 1

        if prev_tid in workers:
            switch_out[prev_tid] += 1
            state = field(line, "prev_state")
            states[prev_tid][state] += 1

    elif " sched_waking:" in line:
        tid = field(line, "tid")
        if tid in workers:
            waking[tid] += 1

    elif " sched_wakeup_new:" in line:
        tid = field(line, "tid")
        if tid in workers:
            wakeup_new[tid] += 1

    elif " sched_wakeup:" in line:
        tid = field(line, "tid")
        if tid in workers:
            wakeup[tid] += 1

if proc.wait() != 0:
    raise SystemExit("Babeltrace failed")

print("Worker Scheduler State Analysis")
print("=" * 55)

for tid in workers:
    print(f"\nWorker TID: {tid}")
    print(f"Schedule-ins: {switch_in[tid]}")
    print(f"Schedule-outs: {switch_out[tid]}")
    print(f"Previous states: {dict(sorted(states[tid].items()))}")
    print(f"Waking events: {waking[tid]}")
    print(f"Wakeup events: {wakeup[tid]}")
    print(f"Wakeup-new events: {wakeup_new[tid]}")
