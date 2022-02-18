# Bazel rules for GHDL

Disclaimer: Consider this version 0.1 :)

The rules are currently only support runnning on linux.

The repository is design to be self sustained but does depend on
having gnat and llvm installed on your system.

```console
$ sudo apt-get install -y gnat
$ sudo apt-get install -y llvm
```

This repository makes use bazelisk with handles download of bazel
on your system, however, note the .bazeliskrc.
Which specifies the bazel version. This repository does not
yet support bazel 5.0 for instance.

install instructions here:
https://docs.bazel.build/versions/main/install-bazelisk.html

If you have installed the above mentioned dependencies
you should be able to run the below commands and
bazelisk will pull down bazel with the version specified in
.bazeliskrc.

In turn this repository has a dependency on the ghdl source,
and will build that for you, so the first command, 
will take some time.

Thankfully after that everything should be smooth.

Since you want to use these rules as a dependency in your own
project there are some convenience functions for you to use in
your WORKSPACE file.

```console
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
  name = "rules_ghdl",
  sha256 = "9ca5084e414c5e302f2ce087377d5694e3515af2e5c1b12b9f44a2a1490bf33d",
  urls = [
    "https://github.com/solsjo/rules_ghdl/archive/refs/heads/main.zip"
  ],
  strip_prefix = "rules_ghdl-main"
)

load("@rules_ghdl//:load_rules_ghdl_deps.bzl", "load_rules_ghdl_deps")
load_rules_ghdl_deps()
load("@rules_ghdl//:rules_ghdl_deps.bzl", "rules_ghdl_deps")
rules_ghdl_deps()

register_toolchains(
  "//:ghdl_linux_toolchain",
)

```

If just want to pull down this repository and try it out,
just clone, install the dependencies and run any of the 
following:

```console
$ bazelisk build @rules_ghdl//test:counter

```

```console
$ bazelisk build @ghdl_example//...

```

```console
$ bazelisk build @ghdl_example//... --sandbox_debug

```
