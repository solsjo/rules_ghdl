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
    "lib/ghdl",
]

filegroup(
    name = "ghdl_bin_ghdl",
    srcs = ["bin/ghdl"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "ghdl_bin_ghdl_dir",
    srcs = ["bin"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "ghdl_bin",
    srcs = ghdl_files,
    visibility = ["//visibility:public"],
)

genrule(
    name = "ghdl-srcs",
    outs = ghdl_files,
    cmd = "\n".join([
        'export INSTALL_DIR=$$(pwd)/$(@D)',
        'export TMP_DIR=$$(mktemp -d -t ghdl.XXXXX)',
        'mkdir -p $$TMP_DIR',
        'cp -R $$(pwd)/../../../../../external/ghdl_toolchain/* $$TMP_DIR',
        'cd $$TMP_DIR',
        'mkdir build',
        'cd build',
        '../configure --with-llvm-config --prefix=$$INSTALL_DIR',
        'make',
        'make install',
        'rm -rf $$TMP_DIR',
    ]),
)
