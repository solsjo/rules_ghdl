# A provider with one field, transitive_sources.
GHDLFiles = provider(
    fields = [
        "transitive_sources",
        "outs",
        "lib_name",
        "src_map",
    ]
)

def get_dir(dep):
  return dep.dirname

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

def _prepare_cfg_file_content(ctx, args, i_path, lib_name, old_cfg):

    # cfg file generation
    new_lib_file = ctx.actions.declare_file(i_path + "/" + "work-obj08.cf")
    curr_src_lib_paths = new_lib_file.dirname.split(lib_name)
    work_dir = curr_src_lib_paths[0] + lib_name
    args.add(old_cfg.path)
    args.add(new_lib_file.path)
    args.add("cd " + work_dir)
    args.add("&&")
   
    return new_lib_file

def _prepare_hdl_files(ctx, i_path, src):

    # o file generation
    out_name = "{}.o".format(i_path + "/" + src.basename.split(".")[0])
    out_o = ctx.actions.declare_file(out_name)

    sym_src = ctx.actions.declare_file(i_path + "/" + src.path)
    ctx.actions.symlink(output=sym_src, target_file=src)

    return sym_src, out_o

def _ghdl_units_impl(ctx):
    # To not pick a fight with the internals of ghdl, the compilation of any
    # vhd file is delayed to the ghdl_binary rule.
    # So ghdl units is only a collection phase.

    trans_srcs = get_transitive_srcs(
        ctx.files.srcs,
        ctx.attr.deps
    )

    lib_id = ctx.label.workspace_name + "/" + ctx.attr.lib[GHDLFiles].lib_name

    unit_settings = []
    unit_lib_deps = []
    src_map = {}

    for dep in ctx.attr.deps:
        src_map.update(dep[GHDLFiles].src_map)
        for src, settings in dep[GHDLFiles].src_map.items():
            if lib_id != settings["lib_name"]:
                unit_lib_deps.append(settings["lib_name"])

    for src in ctx.files.srcs:
        src_map[src]={
            "unit_lib_deps": unit_lib_deps,
            "lib_name": lib_id,
            "unit_settings": unit_settings}

    return [
        DefaultInfo(files = depset(trans_srcs)),
        GHDLFiles(transitive_sources=trans_srcs, lib_name=lib_id, src_map=src_map)
    ]


def _ghdl_testbench_impl(ctx):
    info = ctx.toolchains["//:ghdl_toolchain_type"].ghdlinfo
   
    trans_srcs = get_transitive_srcs(
        ctx.files.srcs,
        ctx.attr.deps
        )
    srcs = trans_srcs.to_list()
    outs = []
    lib_cfg_map = {}
    compiled_output_files = []
    i = 0
    out_o = None
    sym_o_files = []
    sym_srcs = []
    _symed_sources = []

    src_map = {}
    for dep in ctx.attr.deps:
        for src, settings in dep[GHDLFiles].src_map.items():
            if src not in src_map:
                src_map[src] = settings

    for src in srcs:
        lib = src_map[src]["lib_name"]
        lib_name = lib.split("/")[-1]

        p_deps = []
        for lib in src_map[src]["unit_lib_deps"]:
            p_deps.append(lib_cfg_map[lib])

        # TODO: test setting to None instead
        if lib not in lib_cfg_map:
            lib_cfg_map[lib] = ctx.attr._initial_lib_file.files.to_list()[0]
        curr_lib_file = lib_cfg_map[lib]

        i_path = str(i) + "/" + src.basename.split(".")[0] + "/" + lib_name
        args = ctx.actions.args()
        new_lib_file = _prepare_cfg_file_content(
            ctx,
            args,
            i_path,
            lib_name,
            curr_lib_file,
        )
        sym_src, out_o = _prepare_hdl_files(ctx, i_path, src)
        args.add("ghdl")
        args.add("-a")
        args.add("--std=08")
        args.add("--ieee=synopsys --warn-no-vital-generic") # TODO: make flags an option instead
        args.add("--work=work") 
        args.add_all(p_deps, format_each="-P%s", map_each=get_dir)
        args.add(src.path)
        ctx.actions.run(
            mnemonic = "ghdlWrapper",
            executable = info.compiler_path.files.to_list()[0].path,
            tools = [info.compiler_path.files.to_list()[0]],
            arguments = [args],
            inputs = [curr_lib_file, sym_src],
            outputs = [new_lib_file, out_o],
        )

        # Update lib file used for the lib
        lib_cfg_map[lib]=new_lib_file

        # Save the output files, they will be needed later, in the
        # elaboration stage.
        compiled_output_files.append(out_o)

        # Save the input files, they will be needed later, in the
        # elaboation stage
        sym_srcs.append(sym_src)
        i = i + 1

    # Last used path, why do we use this?
    i_path = str(i) + "/" + src.basename.split(".")[0] + "/" + lib_name

    for i in range(len(srcs)):
        o_file = compiled_output_files[i]
        out_name = "{}".format(i_path + "/" + o_file.basename)
        d = ctx.actions.declare_file(out_name)
        sym_o_files.append(d)
        ctx.actions.symlink(output=d, target_file=o_file)
          
        src = srcs[i]
        x = ctx.actions.declare_file(i_path + "/" + src.path)
        ctx.actions.symlink(output=x, target_file=src)
        _symed_sources.append(x)
   
    test_bin = ctx.actions.declare_file(ctx.attr.entity_name)
    curr_lib_file = lib_cfg_map[lib]
    #new_lib_file = ctx.actions.declare_file(i_path + "/" + "work-obj08.cf")

    args = ctx.actions.args()
    args = ctx.actions.args()
    new_lib_file = _prepare_cfg_file_content(
        ctx,
        args,
        i_path,
        lib_name,
        curr_lib_file,
    )
    args.add("ghdl")
    args.add("-e")
    args.add("-o {}".format(test_bin.basename))
    args.add("--std=08")
    args.add("--ieee=synopsys --warn-no-vital-generic") # TODO: make flags an option instead
    args.add("--work=work") 
    args.add_all(lib_cfg_map.values(), format_each="-P%s", map_each=get_dir)
    args.add(test_bin.basename)
    args.add("&&")
    args.add("cd -")
    args.add("&&")
    args.add("cp " + str(sym_o_files[-1].dirname.split(lib_name)[0]) + lib_name + "/" + test_bin.basename +" " + str(test_bin.path))
    ctx.actions.run(
        mnemonic = "ghdl",
        executable = info.compiler_path.files.to_list()[0].path,
        tools = [info.compiler_path.files.to_list()[0]],
        arguments = [args],
        inputs = [curr_lib_file] + compiled_output_files + [ctx.attr._initial_lib_file.files.to_list()[0]] + srcs + sym_srcs + _symed_sources + lib_cfg_map.values() + sym_o_files,
        outputs = [new_lib_file, test_bin],
    )

    return [
        DefaultInfo(files = depset([test_bin])),
        GHDLFiles(transitive_sources=trans_srcs, outs=[test_bin])
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

ghdl_testbench = rule(
    implementation = _ghdl_testbench_impl,
    attrs = {
        "entity_name": attr.string(mandatory=True),
        "srcs": attr.label(allow_single_file = [".vhd", ".v"], mandatory = True),
        "deps": attr.label_list(),
        "_initial_lib_file": attr.label(allow_single_file=True, default="//:initial_lib_file")
    },
    toolchains = ["@rules_ghdl//:ghdl_toolchain_type"]
)
