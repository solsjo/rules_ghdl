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


def _prepare_cfg_file_content(ctx, args, working_dir, lib_name, old_cfg):

    # cfg file generation
    new_lib_file_path = "{}/{}".format(working_dir, "{}-obj08.cf".format(lib_name))
    new_lib_file = ctx.actions.declare_file(new_lib_file_path)
    curr_src_lib_paths = new_lib_file.dirname.split(lib_name)
    work_dir = "{}{}".format(curr_src_lib_paths[0], lib_name)

    if old_cfg:
        args.append("cp {} {}".format(old_cfg.path, new_lib_file.path))
        args.append("&&")
    args.append("cd {}".format(work_dir))
    args.append("&&")

    return new_lib_file


def _prepare_hdl_files(ctx, working_dir, src):

    # o file generation
    file_name = src.basename.split(".")[0]
    out_name = "{}/{}.o".format(working_dir, file_name)
    out_o = ctx.actions.declare_file(out_name)

    sym_src_path = "{}/{}".format(working_dir, src.path)
    sym_src = ctx.actions.declare_file(sym_src_path)
    ctx.actions.symlink(output=sym_src, target_file=src)

    return sym_src, out_o


def _ghdl_units_impl(ctx):
    # GHDL employes a library config file, that is updated on analysis
    # of each unit belonging to the library.
    # The format of the config is GHDL internal.
    # bazel on the other hand will treat the output of an action as
    # immutable, so that builds can be hermetic.
    # Therefore we aren't allowed to update the config in the next analysis
    # action.
    # So, to simplify and to not pick a fight with the internals of ghdl
    # and allow shareable bazel action cache artifacts.
    # The compilation of any hdl file is delayed until elaboration can
    # be performed.
    # So ghdl units is only a collection phase.
    # To still allow updates of the config file, the library file is
    # copied for each action where it is needed.

    trans_srcs = get_transitive_srcs(
        ctx.files.srcs,
        ctx.attr.deps
    )

    lib_id = "{}/{}".format(ctx.label.workspace_name, ctx.attr.lib[GHDLFiles].lib_name)

    unit_settings = []
    unit_lib_deps = []
    src_map = {}

    # TODO: Use a set instead, also, should probably only add direct deps and not
    # transitive
    for dep in ctx.attr.deps:
        src_map.update(dep[GHDLFiles].src_map)
        for src, settings in dep[GHDLFiles].src_map.items():
            if lib_id != settings["lib_name"]:
                unit_lib_deps.append(settings["lib_name"])

    for src in ctx.files.srcs:
        src_map[src]={
            "unit_lib_deps": unit_lib_deps,
            "lib_name": lib_id,
            "unit_settings": unit_settings,
            "flags": ctx.attr.flags
            }

    return [
        DefaultInfo(files = depset(trans_srcs)),
        GHDLFiles(transitive_sources=trans_srcs, lib_name=lib_id, src_map=src_map)
    ]


def _ghdl_testbench_impl(ctx):
    info = ctx.toolchains["@rules_ghdl//:ghdl_toolchain_type"].ghdlinfo
    ghdl_tool = info.compiler_path.files.to_list()[0]

    trans_srcs = get_transitive_srcs(
        ctx.files.srcs,
        ctx.attr.deps
        )

    srcs = trans_srcs.to_list()
    _elaboration_sym_srcs = []

    lib_cfg_map = {}

    out_o = None
    compiled_output_files = []
    sym_o_files = []
    comp_srcs = []
    _lib_sym_srcs = []

    outs = []

    src_map = {}
    for dep in ctx.attr.deps:
        for src, settings in dep[GHDLFiles].src_map.items():
            if src not in src_map:
                src_map[src] = settings

    for src in srcs:
        lib = src_map[src]["lib_name"]
        lib_name = lib.split("/")[-1]
        flags = src_map[src]["flags"]

        p_deps = {}
        inputs = []
        for dep_lib in src_map[src]["unit_lib_deps"]:
            # always use latest version
            p_deps[dep_lib] = lib_cfg_map[dep_lib]


        if lib not in lib_cfg_map:
            lib_cfg_map[lib] = None
        else:
            inputs.append(lib_cfg_map[lib])
        curr_lib_file = lib_cfg_map[lib]

        working_dir = "objs/{}/{}".format(src.basename.split(".")[0], lib_name)
        args = [] #ctx.actions.args()
        new_lib_file = _prepare_cfg_file_content(
            ctx,
            args,
            working_dir,
            lib_name,
            curr_lib_file,
        )

        for i in range(len(comp_srcs)):
            comp_src = comp_srcs[i]
            _lib_sym_src_path = "{}/{}".format(working_dir, comp_src.path)
            lib_sym_src = ctx.actions.declare_file(_lib_sym_src_path)
            ctx.actions.symlink(output=lib_sym_src, target_file=comp_src)
            _lib_sym_srcs.append(lib_sym_src)
        inputs.extend(_lib_sym_srcs)
        inputs.extend(comp_srcs)
        sym_src, out_o = _prepare_hdl_files(ctx, working_dir, src)
        inputs.append(sym_src)
        inputs.extend(p_deps.values())
        args.append("ghdl")
        args.append("-a")
        args.append("--std=08")
        args.append("--ieee=synopsys --warn-no-vital-generic")
        args.extend(flags)
        args.append("--work={}".format(lib_name))
        #args.append_all(p_deps.values(), format_each="-P%s", map_each=get_dir)
        for pdep in p_deps.values():
          args.append("-P../../../../../../../../{}".format(get_dir(pdep)))
        args.append("-P./")  # Include current lib
        args.append(src.path)
        ctx.actions.run_shell(
            mnemonic = "ghdlAnalysis",
            #executable = ghdl_tool.path,
            #tools = [ghdl_tool],
            #arguments = [args],
            use_default_shell_env = True,
            command = " ".join(args),
            inputs = inputs,
            outputs = [new_lib_file, out_o],
        )

        # Update lib file used for the lib
        lib_cfg_map[lib]=new_lib_file

        # Save the output files, they will be needed later, in the
        # elaboration stage.
        compiled_output_files.append(out_o)
        comp_srcs.append(src)

    working_dir = "bin/{}/{}".format(src.basename.split(".")[0], lib_name)
    tb_file = src
    sym_cf_files = []


    for i in range(len(srcs)):
        # Check if src file belongs to current lib, if so, create symlinks in current dir,
        # else create symlinks to library dir for that library in bin folder, as well as
        # the cf file and change -P to point there too?
        # Or create symlinks into the same lib base dir as where the srcs are stored in bin
        if src_map[srcs[i]]["lib_name"] == lib:
            o_file = compiled_output_files[i]
            out_name = "{}/{}".format(working_dir, o_file.basename)
            sym_o_file = ctx.actions.declare_file(out_name)
            sym_o_files.append(sym_o_file)
            ctx.actions.symlink(output=sym_o_file, target_file=o_file)
            
            src = srcs[i]
            _elaboration_sym_src_path = "{}/{}".format(working_dir, src.path)
            elaboration_sym_src = ctx.actions.declare_file(_elaboration_sym_src_path)
            ctx.actions.symlink(output=elaboration_sym_src, target_file=src)
            _elaboration_sym_srcs.append(elaboration_sym_src)
        else:
            src = srcs[i]
            o_file = compiled_output_files[i]
            lib_working_dir = "bin/{}/{}".format(tb_file.basename.split(".")[0], src_map[src]["lib_name"])
            out_name = "{}/{}".format(lib_working_dir, o_file.basename)
            sym_o_file = ctx.actions.declare_file(out_name)
            sym_o_files.append(sym_o_file)
            ctx.actions.symlink(output=sym_o_file, target_file=o_file)
            print("\n--other_lib: {}\n--comp: {}\n--file: {}\n".format(lib, src_map[src]["lib_name"], sym_o_file.path))
            
            _elaboration_sym_src_path = "{}/{}".format(lib_working_dir, src.path)
            elaboration_sym_src = ctx.actions.declare_file(_elaboration_sym_src_path)
            ctx.actions.symlink(output=elaboration_sym_src, target_file=src)
            _elaboration_sym_srcs.append(elaboration_sym_src)

    for name, t_dep in p_deps.items():
        print("\nname={}:t_dep={}\n".format(name, t_dep))
        if name != lib:
            lib_working_dir = "bin/{}/{}".format(tb_file.basename.split(".")[0], name)
            out_name = "{}/{}".format(lib_working_dir, t_dep.basename)
            sym_cf_file = ctx.actions.declare_file(out_name)
            sym_cf_files.append(sym_cf_file)
            ctx.actions.symlink(output=sym_cf_file, target_file=t_dep)
            print(sym_cf_file.path)
            
    print(sym_cf_files)
    files_to_link = []
    files_to_link.extend(compiled_output_files)
    files_to_link.extend(sym_o_files)

    src_files = []
    src_files.extend(srcs)
    src_files.extend(_elaboration_sym_srcs)

    test_bin = ctx.actions.declare_file("{}/{}".format(working_dir,ctx.attr.entity_name))
    curr_lib_file = lib_cfg_map[lib]

    args = []#ctx.actions.args()
    new_lib_file = _prepare_cfg_file_content(
        ctx,
        args,
        working_dir,
        lib_name,
        curr_lib_file,
    )

    elab = "--elab"
    add_no_run = False
    if ctx.attr.elab_flags or ctx.attr.generics:
        elab = "--elab-run"
        add_no_run = True
        

    args.append("ghdl")
    args.append(elab)
    args.append("-o {}".format(test_bin.basename))
    args.append("--std=08")
    args.append("--ieee=synopsys --warn-no-vital-generic")
    args.append("--work={}".format(lib_name))
    #args.append_all(lib_cfg_map.values(), format_each="-P%s", map_each=get_dir)
    #for lib_cfg in lib_cfg_map.values():
    #args.append("-P./")  # Include current lib
    for sym_cf in sym_cf_files:
      args.append("-P../../../../../../../../{}".format(get_dir(sym_cf)))
    args.append(test_bin.basename)
    for generic in ctx.attr.generics:
      args.append(generic)
    if add_no_run:
      args.append("--no-run")

    print(args)
    ctx.actions.run_shell(
        mnemonic = "ghdlElaboration",
        #executable = ghdl_tool.path,
        #tools = [ghdl_tool],
        #arguments = [args],
        use_default_shell_env = True,
        command = " ".join(args),
        inputs = [curr_lib_file] + files_to_link + src_files + lib_cfg_map.values() + sym_cf_files,
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
        "flags": attr.string_list(mandatory=False, allow_empty=True)
    },
)

def _ghdl_library_impl(ctx):
    return [
        GHDLFiles(lib_name=ctx.label.name)
    ]


ghdl_library = rule(
    implementation = _ghdl_library_impl,
)

# TODO: Should probably be renamed to ghdl_elaboration
ghdl_testbench = rule(
    implementation = _ghdl_testbench_impl,
    attrs = {
        "entity_name": attr.string(mandatory=True),
        # TODO: Remove sources from testbench rule
        "srcs": attr.label(allow_single_file = [".vhd", ".v"], mandatory = True),
        "deps": attr.label_list(),

        "elab_flags" : attr.string_list(mandatory=False, allow_empty=True),
        "generics" : attr.string_list(mandatory=False, allow_empty=True), # Should be dict

    },
    toolchains = ["@rules_ghdl//:ghdl_toolchain_type"]
)
