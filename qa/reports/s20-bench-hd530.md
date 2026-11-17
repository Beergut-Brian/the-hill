# S-20 bench on the TV box's Intel HD 530

- Dates: 2026-11-15 (20:38, 20:39) and 2026-11-16 (08:28, 08:29)
- Box: the TV box, Intel HD Graphics 530 (SKL GT2), i5-6400, 1080p
- Build: the-hill v0.2.2-dev.2 (release)
- Run: `--bench`, split screen, 60 s, `low` tier auto-picked (`tier=low` in every BENCH line)

```
== 2026-11-15 20:39 run (box-hill-low-bench-2026-11-15b.log)
BENCH avg=59.3 low1=35.7 ms=16.85 worst=33.21 frames=3502 tier=low
HITCH count>33ms=1 worst=33.21
== 2026-11-15 run c (box-hill-low-bench-2026-11-15c.log)
BENCH avg=59.2 low1=35.7 ms=16.90 worst=31.12 frames=3490 tier=low
HITCH count>33ms=0 worst=31.12
== 2026-11-16 runs (box-hill-low-bench-2026-11-16.out)
BENCH avg=59.4 low1=36.4 ms=16.83 worst=33.21 frames=3507 tier=low
HITCH count>33ms=1 worst=33.21
BENCH avg=59.0 low1=35.1 ms=16.94 worst=31.25 frames=3483 tier=low
HITCH count>33ms=0 worst=31.25
```

These are the producer's numbers taken on the TV box's own screen with the built-in bench; the TV itself is still to be checked.

## Checked against the logs

The numbers match the producer's logs in `lanes/logs/` (readable from this worktree's host). One label differs: the 20:39 run on 2026-11-15 (avg 59.3, worst 33.21) is in `box-hill-low-bench-2026-11-15c.log`, not `...15b.log`. The `15b` log only holds a failed start (no Wayland display, no BENCH line). `15c` holds both the 20:38 and 20:39 runs. The block above keeps the producer's labels.

## Row S-20 (Producer 2026-11-14)

"Steady 30 fps minimum, 60 where it can": passes.

- 1%-low is 35.1 to 36.4 fps on all four runs, above 30.
- Average is 59.0 to 59.4 fps against a 60 target.
- Worst single frame is 31.12 to 33.21 ms (about 30 fps). At most one frame over 33 ms in about 3,500.
- `low` tier was picked from the adapter with no flag; the bench is built in.
