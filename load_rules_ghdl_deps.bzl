"""Load dependencies needed to compile a ghdl binary as a 3rd-party consumer."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def load_rules_ghdl_deps():
    """Loads common dependencies needed to compile a ghdl binary."""
    
    if not native.existing_rule("bazel_skylib"):
        http_archive(
            name = "bazel_skylib",
            urls = [
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
            ],
            sha256 = "c6966ec828da198c5d9adbaa94c05e3a1c7f21bd012a0b29ba8ddbccb2c93b0d",
        )
    
    if not native.existing_rule("ghdl_toolchain"):
        http_archive(
            name = "ghdl_toolchain",
            urls = [
                "https://github.com/ghdl/ghdl/releases/download/v0.37/ghdl-0.37-ubuntu16-llvm-3.9.tgz"
            ],
            sha256 = "3068e3eebe8aa22865b75cb271f60c6a90872181e8d50e2eb44a34f7fe9ae169",
            strip_prefix = "ghdl-0.37-ubuntu16-llvm-3.9",
            build_file = "@rules_ghdl//src/ghdl_toolchain.BUILD"
        )
