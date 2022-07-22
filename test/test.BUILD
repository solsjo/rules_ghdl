load("@rules_ghdl//:ghdl.bzl", "ghdl_units", "ghdl_library", "ghdl_elab")

ghdl_library(name="ghdl_example_lib")

ghdl_units(
    name = "counter",
    srcs = [
        ":source/counter.vhd",
    ],
    deps = [],
    lib = ":ghdl_example_lib"
)

ghdl_elab(
    name = "ghdl_example_tb",
    entity_name = "counter_tb",
    arch = "testbench",
    top = ":testbench/counter_tb.vhd",
    lib = ":ghdl_example_lib",
    deps = [":counter"]
)
