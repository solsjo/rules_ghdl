load(":toolchain.bzl", "ghdl_toolchain")

toolchain_type(name = "ghdl_toolchain_type",
               visibility = ["//visibility:public"],)

ghdl_toolchain(
    name = "ghdl_linux",
    # TODO: arch flags isn't used yet, and might not be used in the future
    # either, it exists as a placeholder
    arch_flags = [
        "--arch=Linux",
        "--debug_everything",
    ],
    #compiler_path = "", # by default a docker image is used instead of the
    # local toolchain.
    visibility = ["//visibility:public"],
)

platform(
    name = "linux_platform",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
)

toolchain(
    name = "ghdl_linux_toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    toolchain = "//:ghdl_linux",
    toolchain_type = ":ghdl_toolchain_type",
)

filegroup(
    name="readme",
    srcs=["README.md"]
)
