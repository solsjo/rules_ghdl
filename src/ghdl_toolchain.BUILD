filegroup(
    name = "ghdl_deps",
    srcs = glob([
        "lib/ghdl/**/*.*",
        "lib/*gh.*",
        "include/**/*.*",
        "bin/ghdl-llvm/**/*.*",
    ]) + [":ghdl_bin"],
    visibility = ["//visibility:public"],
)

ghdl_files = [
    "bin/ghdl",
    "bin/ghdl1-llvm",
    "bin/ghwdump"
]

filegroup(
    name = "ghdl_bin",
    srcs = ghdl_files,
    visibility = ["//visibility:public"],
)

genrule(
    name = "ghdl-srcs",
    outs = ghdl_files,
    cmd = "\n".join([
        'mkdir bin',
        'export INSTALL_DIR=$$(pwd)/bin',
        'mkdir build',
        'ls -la $$(pwd)/bazel-out && cd build',
        '../configure --with-llvm-config --prefix=$$INSTALL_DIR',
        'make',
        'make install'
    ]),
)
