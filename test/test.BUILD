load("@rules_ghdl//:ghdl.bzl", "ghdl_units", "ghdl_library", "ghdl_testbench")

ghdl_library(name="ghdl_example_lib")

ghdl_units(
    name = "counter",
    srcs = [
        ":source/counter.vhd",
    ],
    deps = [],
    lib = ":ghdl_example_lib"
)

ghdl_units(
    name = "counter_tb",
    srcs = [
        "testbench/counter_tb.vhd",
    ],
    deps = [":counter"],
    lib = ":ghdl_example_lib"
)

ghdl_testbench(
    name = "ghdl_example_tb",
    entity_name = "counter_tb",
    arch = "testbench",
    srcs = ":testbench/counter_tb.vhd",
    deps = [":counter_tb"]
)
