import re
import subprocess
from collections import Counter

trace = "logs/lttng/matrix4-v2-gui/kernel"
workers = [8747, 8748, 8749, 8750]

cpu_counts = {tid: Counter() for tid in workers}
last_cpu = {}
changes = Counter()
transitions = {tid: [] for tid in workers}

proc = subprocess.Popen(
    ["babeltrace", trace],
    stdout=subprocess.PIPE,
    text=True
)

for line in proc.stdout:
    if "sched_switch:" not in line:
        continue

    cpu_match = re.search(r"\bcpu_id = (\d+)", line)
    tid_match = re.search(r"\bnext_tid = (\d+)", line)

    if not cpu_match or not tid_match:
        continue

    cpu = int(cpu_match.group(1))
    tid = int(tid_match.group(1))

    if tid not in workers:
        continue

    cpu_counts[tid][cpu] += 1

    if tid in last_cpu and last_cpu[tid] != cpu:
        changes[tid] += 1
        if len(transitions[tid]) < 8:
            transitions[tid].append(
                f"{last_cpu[tid]} -> {cpu}"
            )

    last_cpu[tid] = cpu

if proc.wait() != 0:
    raise SystemExit("Babeltrace failed")

print("Worker CPU Placement Analysis")
print("=" * 65)

for tid in workers:
    print(f"\nWorker TID: {tid}")
    print(f"Schedule-ins: {sum(cpu_counts[tid].values())}")
    print(f"CPUs used: {sorted(cpu_counts[tid])}")
    print(f"Observed CPU changes: {changes[tid]}")
    print(f"Schedule-ins per CPU: {dict(sorted(cpu_counts[tid].items()))}")
    print(f"First transitions: {transitions[tid]}")
