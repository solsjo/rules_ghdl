workspace(name = "rules_ghdl")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

new_local_repository(
     name = "ghdl_toolchain",
     path = "/home/runner/work/_temp/ghdl",
     build_file = "@rules_ghdl//src:ghdl_toolchain.BUILD",
)

load("@rules_ghdl//:load_rules_ghdl_deps.bzl", "load_rules_ghdl_deps")
load_rules_ghdl_deps()
load("@rules_ghdl//:rules_ghdl_deps.bzl", "rules_ghdl_deps")
rules_ghdl_deps()

register_toolchains(
    "//:ghdl_linux_toolchain",
)

register_execution_platforms("//:linux_platform")

http_archive(
    name = "ghdl_example",
    urls = ["https://github.com/jimtremblay/ghdl-example/archive/refs/heads/master.zip"],
    sha256 = "0f37f4f804b5189c244e6acd14cf88f8e0d3ffb4a8967655a45559b2ccd8334a",
    strip_prefix = "ghdl-example-master",
    build_file = "@rules_ghdl//test:test.BUILD"
)
