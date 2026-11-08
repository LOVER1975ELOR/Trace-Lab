Lab 1 submission
Mahdi Davoodzadeh - Student number 405725536

Start with Lab1_OS_Tracing_Report.pdf.

Contents:
- src/simple_program.c: supplied C program.
- output.txt: sample output file produced by the program.
- logs/strace/: detailed parent-only and child-following traces and summaries.
- logs/lttng/matrix4-v2-gui/kernel/: complete successful kernel trace in CTF format, including metadata and stream indexes.
- logs/lttng/: successful session configuration, workload metrics, and kernel-module validation logs.
- notes/: recorded environment, derived measurements, and analysis scripts.
- screenshots/: original images used by the PDF, excluding 13.png and 15.png.

Trace inspection:
Import logs/lttng/matrix4-v2-gui/kernel/ into Trace Compass as an LTTng kernel trace.
The scheduler trace was recorded on kernel 6.17.0-40-generic.
The earlier environment snapshot records kernel 7.0.0-42-generic before the kernel change.

To rerun the supplied analysis scripts, install Babeltrace and run from this lab1 directory:
python3 notes/analyze_worker_cpu.py
python3 notes/analyze_worker_states.py

To compile the C program, run from this lab1 directory:
mkdir -p bin
gcc -g -O0 -Wall -Wextra src/simple_program.c -o bin/simple_program

The report captions are numbered sequentially from Figure 1 to Figure 20.
Original screenshots 13.png and 15.png remain excluded; screenshot filenames are unchanged.
Markdown drafts, compiled binaries, downloaded tools, reference repositories, and duplicate or trial trace directories are excluded.
