GHDLInfo = provider(
    doc = "Information about how to invoke the ghdl compiler.",
    fields = ["compiler_path", "docker", "wrapper", "compiler_deps", "c_compiler"],
)

def _ghdl_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        ghdlinfo = GHDLInfo(
            compiler_path = ctx.attr.compiler_path,
            docker = ctx.attr.docker,
            wrapper = ctx.attr.wrapper,
            compiler_deps = ctx.attr.compiler_deps,
            c_compiler = ctx.attr.c_compiler,
        ),
    )
    return [toolchain_info]

ghdl_toolchain = rule(
    implementation = _ghdl_toolchain_impl,
    attrs = {
        "compiler_path": attr.label(default="@ghdl_toolchain//:ghdl_bin"),
        "docker": attr.string(),
        "wrapper": attr.label(default="@rules_ghdl//src:default_ghdl"),
        "compiler_deps": attr.label(default="@ghdl_toolchain//:ghdl_deps"),
        "c_compiler": attr.string(default="/usr/bin/clang"),
    },
)
