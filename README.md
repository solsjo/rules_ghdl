#bazel rules for GHDL

The rules are currently only tested on linux and most probably doesn't
work on windows, there is also no toolchain set up for windows.

By default the toolchains compiler path points inside the repo, to
a shell script src/ghdl.sh.
This shell scripts executes the ghdl command inside a docker container,
this is only for convenience.
One can register your own toolchain and point to the real path locally.
Another suggestion is to add ghdl as an external non bazel repository,
and let bazel build it for you; and point the compiler_path to that target.

Example use:

external non bazel repository

```console
$ bazelisk build @ghdl_example//:ghdl_example
foo
```

tests:

```console
$ bazelisk build @rules_ghdl//test:counter
```

