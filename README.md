# LMC Interpreter

## Build prerequisites

- [zig](https://ziglang.org/)
- any POSIX shell (optional, for `run.sh`)

## Assemble and run

`run.sh` assembles LMC source to a binary at `/tmp/lmc-out`, then runs the binary.

`./examples/run.sh /path/to/source.s`

## Open the debugger command line

The debugger command line allows memory and register inspection, assembling from a file, and running LMC programs.
Use `help` to get a list of commands.

`zig build lmc-dbg`

## Assemble

Assemble LMC source to a binary.

`zig build lmc-as </path/to/source.s >/path/to/executable`

## Run

Interpret an LMC binary.

`zig build lmci -- /path/to/executable`
