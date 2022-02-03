GHDLInfo = provider(
    doc = "Information about how to invoke the ghdl compiler.",
    fields = ["compiler_path", "docker", "wrapper", "compiler_deps"],
)

def _ghdl_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        ghdlinfo = GHDLInfo(
            compiler_path = ctx.attr.compiler_path,
            docker = ctx.attr.docker,
            wrapper = ctx.attr.wrapper,
            compiler_deps = ctx.attr.compiler_deps,
        ),
    )
    return [toolchain_info]

ghdl_toolchain = rule(
    implementation = _ghdl_toolchain_impl,
    attrs = {
        "compiler_path": attr.label(default="@ghdl_toolchain//:ghdl_bin"),
        "docker": attr.string(),
        "wrapper": attr.label(default="@ghdl_rules//src:default_ghdl"),
        "compiler_deps": attr.label(default="@ghdl_toolchain//:ghdl_deps")
    },
)
