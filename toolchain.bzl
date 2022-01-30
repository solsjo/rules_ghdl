GHDLInfo = provider(
    doc = "Information about how to invoke the ghdl compiler.",
    fields = ["ghdl_bin", "docker", "wrapper", "ghdl_deps", "c_compiler"],
)

def _ghdl_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        ghdlinfo = GHDLInfo(
            ghdl_bin = ctx.attr.ghdl_bin,
            docker = ctx.attr.docker,
            wrapper = ctx.attr.wrapper,
            ghdl_deps = ctx.attr.ghdl_deps,
            c_compiler = ctx.attr.c_compiler,
        ),
    )
    return [toolchain_info]

ghdl_toolchain = rule(
    implementation = _ghdl_toolchain_impl,
    attrs = {
        "ghdl_bin": attr.label(default="@ghdl_toolchain//:ghdl_bin"),
        "docker": attr.string(),
        "wrapper": attr.label(default="@rules_ghdl//src:default_ghdl"),
        "ghdl_deps": attr.label(default="@ghdl_toolchain//:ghdl_deps"),
        "c_compiler": attr.string(default="/usr/bin/clang"),
    },
)
