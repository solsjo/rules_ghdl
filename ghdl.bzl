# A provider with one field, transitive_sources.
GHDLFiles = provider(fields = ["transitive_sources", "outs", "dep_map", "lib_map", "lib_name"])


def get_dir(dep):
  return dep[GHDLFiles].outs[0].dirname


def get_short_path(src):
  return src.path


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


def _ghdl_units_impl(ctx):
    # To not pick a fight with the internals of ghdl, the compilation of any
    # vhd file is delayed to the ghdl_binary rule.
    # So ghdl library is only a collection phase.

    trans_srcs = get_transitive_srcs(
        ctx.files.srcs,
        ctx.attr.deps
    )

    # Update lib map:
    lib_id = ctx.label.workspace_name + "/" + ctx.attr.lib[GHDLFiles].lib_name
    lib_map = {}
    for dep in ctx.attr.deps:
        for key, values in dep[GHDLFiles].lib_map.items():
            if key not in lib_map:
                lib_map[lib_id] = []
                for value in values:
                    lib_map[lib_id].append(value)
            else:
                for value in values:
                  if value not in lib_map[lib_id]:
                      lib_map[lib_id].append(value)

    if lib_id not in lib_map:
        lib_map[lib_id] = []
    for src in ctx.files.srcs:
       lib_map[lib_id].append(src)

    dep_map = {}
    for src in ctx.files.srcs:
        dep_map[src] = []
        for dep in ctx.attr.deps:
            dep_map.update(dep[GHDLFiles].dep_map.items())
            dep_map[src] += dep[GHDLFiles].lib_map.keys() 

    print(dep_map)
    print(lib_map)

    return [
        DefaultInfo(files = depset(trans_srcs)),
        GHDLFiles(transitive_sources=trans_srcs, dep_map=dep_map, lib_map=lib_map, lib_name=ctx.attr.lib[GHDLFiles].lib_name)
    ]



def _ghdl_testbench_impl(ctx):
    info = ctx.toolchains["//:ghdl_toolchain_type"].ghdlinfo
   
    trans_srcs = get_transitive_srcs(
        ctx.files.srcs,
        ctx.attr.deps
        )
    srcs = trans_srcs.to_list()
    outs = []
    out = ctx.actions.declare_file("counter_tb")
    outs.append(out)
    work_cfg = ctx.actions.declare_file("work-obj93.cf")
    out_name = "{}.o".format(src.basename.split(".")[0])
    out_o = ctx.actions.declare_file(out_name)

    
    # TODO: Consider placing the lib_map in an output from a ghdl_units action
    # so that bazel analysis won't have to be performed again
    # Similar for compilation / simulation flags
    # will need a wrapper script here instead of raw ghdl invocation...
    for src in srcs:
        args = ctx.actions.args()
        args.add("-a")
        args.add("--ieee=synopsys --warn-no-vital-generic") # TODO: make flags an option instead
        args.add("--work=work") 
        args.add("--workdir={}".format(out.dirname))
        args.add_all(ctx.attr.deps, format_each="-P=%s", map_each=get_dir)
        args.add_all(ctx.files.srcs, map_each=get_short_path)
        ctx.actions.run(
            mnemonic = "ghdl",
            executable = info.compiler_path.files.to_list()[0].path,
            tools = [info.compiler_path.files.to_list()[0]],
            arguments = [args],
            inputs = srcs,
            outputs = [work_cfg, out_o],
        )
    

    args = ctx.actions.args()
    args.add("-e")
    args.add("--ieee=synopsys --warn-no-vital-generic") # TODO: make flags an option instead
    args.add("--work=work") 
    args.add("--workdir={}".format(out.dirname))
    args.add_all(ctx.attr.deps, format_each="-P=%s", map_each=get_dir)
    args.add("-o {}".format(out.path))
    args.add(out.basename)

    ctx.actions.run(
        mnemonic = "ghdl",
        executable = info.compiler_path.files.to_list()[0].path,
        tools = [info.compiler_path.files.to_list()[0]],
        arguments = [args],
        inputs = srcs + [work_cfg, out_o],
        outputs = outs,
    )

    return [
        DefaultInfo(files = depset(outs)),
        GHDLFiles(transitive_sources=trans_srcs, outs=outs)
    ]

    
ghdl_units = rule(
    implementation = _ghdl_units_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".vhd", ".v"], mandatory = True),
        "deps": attr.label_list(allow_files = [".vhd", ".v"]),
        "lib": attr.label(),
    },
)

def _ghdl_library_impl(ctx):
    return [
        GHDLFiles(lib_name=ctx.label.name)
    ]


ghdl_library = rule(
    implementation = _ghdl_library_impl,
)

#ghdl_testbench = rule(
#    implementation = _ghdl_testbench_impl,
#    attrs = {
#        "srcs": attr.label(allow_single_file = [".vhd", ".v"], mandatory = True),
#        "deps": attr.label_list(allow_files = [".o", ".a"]),
#    },
#    toolchains = ["//:ghdl_toolchain_type"]
#)
