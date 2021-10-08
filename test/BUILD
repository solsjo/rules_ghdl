load("@rules_ghdl//:ghdl.bzl", "ghdl_units", "ghdl_library")

ghdl_library(name="counter_lib")

ghdl_units(
    name = "counter",
    srcs = [
        ":counter.vhd",
        ":counter2.vhd",
    ],
    deps = [],
    lib = ":counter_lib"
)
