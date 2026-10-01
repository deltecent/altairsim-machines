# Machine tests

Each test boots a committed machine with the `altairsim` on your PATH and checks what reaches the
terminal. Set `ALTAIRSIM=/path/to/altairsim` to test a different binary.

```
tests/run.sh          # every test
tests/run.sh hdsk     # one machine: runs tests/test-hdsk.sh
```

A test copies the machine directory to a scratch directory first, so the committed disk images
stay as they are. With
`MACHINE_SOURCE=zip tests/run.sh`, it unzips `<dir>/<dir>.zip` there instead, which tests the file
that CI builds and people download. Keystrokes come from `tests/keys/`.

To add a machine, write `tests/test-<name>.sh` in the style of `test-hdsk.sh`.
