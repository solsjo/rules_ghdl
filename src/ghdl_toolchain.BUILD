filegroup(
    name = "ghdl_deps",
    srcs = glob([
        "lib/ghdl/**/*.*",
        "lib/*gh.*",
        "include/**/*.*",
        "bin/ghdl-llvm/**/*.*",
    ]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "ghdl_bin",
    srcs = [
        ":bin/ghdl",
        ":bin/ghdl1-llvm",
        ":bin/ghwdump"
    ],
    visibility = ["//visibility:public"],
)
