# A provider with one field, transitive_sources.
GHDLFiles = provider(fields = ["transitive_sources", "outs"])

def get_transitive_srcs(srcs, deps):
  """Obtain the source files for a target and its transitive dependencies.

  Args:
    srcs: a list of source files
    deps: a list of targets that are direct dependencies
  Returns:
    a collection of the transitive sources, and .o files
  """
  return depset(
        srcs,
        transitive = [dep[GHDLFiles].transitive_sources for dep in deps])

def _ghdl_library_impl(ctx):
    info = ctx.toolchains["//:ghdl_toolchain_type"].ghdlinfo
   
    trans_srcs = get_transitive_srcs(
        ctx.files.src,
        ctx.attr.deps
        )
    srcs = trans_srcs.to_list()
    out_name = srcs[0].basename
    out = ctx.actions.declare_file(out_name.split(".")[0] + ".o")

    args = ctx.actions.args()
    #args.add("cd .")
    #args.add("&&")
    args.add("ghdl")
    args.add("-a")
    args.add("--ieee=synopsys --warn-no-vital-generic")
    args.add("--work=work") 
    args.add("{}".format(ctx.file.src.path))

    args.add("&&")
    args.add("mv {} {}".format(ctx.files.src[0].basename.split(".")[0] + ".o", out.path))
    ctx.actions.run(
        mnemonic = "ghdl",
        executable = info.compiler_path.files.to_list()[0].path,
        tools = [info.compiler_path.files.to_list()[0]],
        arguments = [args],
        inputs = srcs,
        outputs = [out],
    )

    return [
        DefaultInfo(files = depset([out])),
        GHDLFiles(transitive_sources=trans_srcs, outs=[out])
    ]

ghdl_library = rule(
    implementation = _ghdl_library_impl,
    attrs = {
        "src": attr.label(allow_single_file = [".vhd", ".v"], mandatory = True),
        "deps": attr.label_list(allow_files = [".vhd", ".v"]),
    },
    toolchains = ["//:ghdl_toolchain_type"]
)
