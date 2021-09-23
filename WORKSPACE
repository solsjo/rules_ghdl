workspace(name = "rules_ghdl")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "platforms",
    sha256 = "a07fe5e75964361885db725039c2ba673f0ee0313d971ae4f50c9b18cd28b0b5",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/platforms/archive/441afe1bfdadd6236988e9cac159df6b5a9f5a98.zip",
        "https://github.com/bazelbuild/platforms/archive/441afe1bfdadd6236988e9cac159df6b5a9f5a98.zip",
    ],
    strip_prefix = "platforms-441afe1bfdadd6236988e9cac159df6b5a9f5a98"
)

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
