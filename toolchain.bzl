GHDLInfo = provider(
    doc = "Information about how to invoke the ghdl compiler.",
    fields = ["compiler_path", "arch_flags"],
)

def _ghdl_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        ghdlinfo = GHDLInfo(
            compiler_path = ctx.attr.compiler_path,
            arch_flags = ctx.attr.arch_flags,
        ),
    )
    return [toolchain_info]

ghdl_toolchain = rule(
    implementation = _ghdl_toolchain_impl,
    attrs = {
        "compiler_path": attr.label(default="//src:default_ghdl"),
        "arch_flags": attr.string_list(),
    },
)
