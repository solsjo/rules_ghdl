load("@bazel_skylib//lib:paths.bzl", "paths")

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
    # ghdl lib file generation

    new_lib_file_path = "{}/{}".format(working_dir, "{}-obj08.cf".format(lib_name))
    new_lib_file = ctx.actions.declare_file(new_lib_file_path)
    curr_src_lib_paths = new_lib_file.dirname.split(lib_name)
    work_dir = "{}{}".format(curr_src_lib_paths[0], lib_name)

    if old_cfg:
        args.add(old_cfg.path)
        args.add(new_lib_file.path)
    else:
        args.add("")
        args.add("")
    args.add("{}".format(work_dir))

    return new_lib_file


def get_execroot_workdir_rel_path(file):
    depth = len(file.dirname.split('/'))
    return "../" * depth


def create_sym_link(ctx, target, sym_link_name, sym_link_path):
    out_name = "{}/{}".format(sym_link_path, sym_link_name)
    sym_link_file = ctx.actions.declare_file(out_name)
    ctx.actions.symlink(output=sym_link_file, target_file=target)
    return sym_link_file


def _prepare_hdl_files(ctx, working_dir, src):
    # o file generation

    file_name = src.basename.split(".")[0]
    out_name = "{}/{}.o".format(working_dir, file_name)
    output_o_file = ctx.actions.declare_file(out_name)

    sym_src_path = "{}/{}".format(working_dir, src.path)
    sym_src = ctx.actions.declare_file(sym_src_path)
    ctx.actions.symlink(output=sym_src, target_file=src)

    return sym_src, output_o_file


def create_compiled_src_symlinks_for_analysis(ctx, working_dir, compiled_srcs):
    sym_linked_srcs = []
    for i in range(len(compiled_srcs)):
        comp_src = compiled_srcs[i]
        _lib_sym_src_path = "{}/{}".format(working_dir, comp_src.path)
        lib_sym_src = ctx.actions.declare_file(_lib_sym_src_path)
        ctx.actions.symlink(output=lib_sym_src, target_file=comp_src)
        sym_linked_srcs.append(lib_sym_src)
    return sym_linked_srcs


def _ghdl_units_impl(ctx):
    # GHDL employes a library config file, that is updated on analysis
    # of each unit belonging to the library.
    # The format of the config is GHDL internal.
    # bazel on the other hand will treat the output of an action as
    # immutable, so that builds can be considered hermetic.
    # Therefore, bazel won't allowed to update the config in the next analysis
    # action.
    # So, to simplify and to not pick a fight with the internals of ghdl
    # and allow shareable bazel action cache artifacts.
    # The compilation of any hdl file is delayed until elaboration can
    # be performed.
    # So ghdl units is only a collection phase.
    # To still allow updates of the config file, the library file is
    # copied for each action where it is needed.
    #
    # Also, since the library file SHA would be affected by different,
    # this ought to provide a re-usable lib file, at least project wise.

    trans_srcs = get_transitive_srcs(
        ctx.files.srcs,
        ctx.attr.deps
    )

    lib_id = "{}/{}".format(ctx.label.workspace_name, ctx.attr.lib[GHDLFiles].lib_name)

    unit_settings = [] # TODO: currently unused
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

def get_dep_libs(lib_cfg_map, unit_lib_deps):
    p_deps = {}

    for dep_lib in unit_lib_deps:
        # always use latest version
        p_deps[dep_lib] = lib_cfg_map[dep_lib]

    return p_deps

def build_source_map(deps):
    src_map = {}
    for dep in deps:
        for src, settings in dep[GHDLFiles].src_map.items():
            if src not in src_map:
                src_map[src] = settings
    return src_map

def get_srcs(ctx):
    trans_srcs = get_transitive_srcs(
        ctx.files.srcs,
        ctx.attr.deps
        )
    srcs = trans_srcs.to_list()
    return srcs


def build_path(start, middle, end):
    return "{}/{}/{}".format(start, middle.basename.split(".")[0], end)


def get_elaboration_artifact(ctx, working_dir):
    elaboration_artifact_name = ctx.attr.entity_name
    if ctx.attr.arch:
        elaboration_artifact_name += "-{}".format(ctx.attr.arch)

    elaboration_artifact = ctx.actions.declare_file("{}/{}".format(working_dir, elaboration_artifact_name))
    return elaboration_artifact_name, elaboration_artifact


def _ghdl_analysis(ctx, info, src, src_map, lib_cfg_map, compiled_output_files, compiled_srcs):
    ghdl_tool = info.wrapper.files.to_list()[0]
    docker = info.docker;
    ghdl_compiler = info.compiler_path.files.to_list()[0]
    ghdl_compiler_deps = info.compiler_deps.files.to_list()
    c_compiler = info.c_compiler;
    args = ctx.actions.args()

    lib = src_map[src]["lib_name"]
    lib_name = lib.split("/")[-1]
    flags = src_map[src]["flags"]
    unit_lib_deps = src_map[src]["unit_lib_deps"]

    p_deps = get_dep_libs(lib_cfg_map, unit_lib_deps).values()
    curr_lib_file = lib_cfg_map.get(lib, default=None)
    working_dir = build_path("objs", src, lib_name)
    new_lib_file = _prepare_cfg_file_content(
        ctx,
        args,
        working_dir,
        lib_name,
        curr_lib_file,
    )
    rel_path = get_execroot_workdir_rel_path(new_lib_file)
    work_dir_symlink_srcs = create_compiled_src_symlinks_for_analysis(ctx, working_dir, compiled_srcs)
    sym_src, output_o_file = _prepare_hdl_files(ctx, working_dir, src)

    inputs = []
    inputs.extend(work_dir_symlink_srcs)
    #inputs.extend(compiled_srcs)
    inputs.append(sym_src)
    if curr_lib_file:
        inputs.append(curr_lib_file)
    inputs.extend(p_deps)

    args.add("./{}{}".format(rel_path, ghdl_compiler.path))
    args.add("-a")
    args.add("--std=08")
    args.add("--ieee=synopsys --warn-no-vital-generic")
    args.add_all(flags)
    args.add("--work={}".format(lib_name))
    args.add_all(p_deps, format_each="-P{}%s".format(rel_path), map_each=get_dir)
    args.add(src.path)
    ctx.actions.run(
        mnemonic = "ghdlAnalysis",
        executable = ghdl_tool.path,
        tools = [ghdl_tool, ghdl_compiler] + ghdl_compiler_deps,
        arguments = [args],
        env = {
            "DOCKER_IMAGE": docker,
            "HOME": "/",
            "CC": c_compiler,
            "GHDL_PREFIX": "{}/../lib/src".format(ghdl_compiler.path),
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"},
        inputs = inputs,
        outputs = [new_lib_file, output_o_file],
    )

    # Update lib file used for the lib
    lib_cfg_map[lib]=new_lib_file

    # Save the output files, they will be needed later, in the
    # elaboration stage.
    return output_o_file


def _ghdl_elaboration(ctx, info, srcs, top_ent_file, src_map, lib_cfg_map, compiled_output_files):
    ghdl_tool = info.wrapper.files.to_list()[0]
    docker = info.docker;
    ghdl_compiler = info.compiler_path.files.to_list()[0]
    ghdl_compiler_deps = info.compiler_deps.files.to_list()
    c_compiler = info.c_compiler;

    lib = src_map[top_ent_file]["lib_name"]
    lib_name = lib.split("/")[-1]
    flags = src_map[top_ent_file]["flags"]
    unit_lib_deps = src_map[top_ent_file]["unit_lib_deps"]

    p_deps = get_dep_libs(lib_cfg_map, unit_lib_deps)
    working_dir = build_path("bin", top_ent_file, lib_name)
    sym_cf_files = []

    symlinked_o_files = []
    _elaboration_sym_srcs = []
    for i in range(len(srcs)):
        # Check if src file belongs to current lib, if so, create symlinks in current dir,
        # else create symlinks to library dir for that library in bin folder, as well as
        # the cf file and change -P to point there too?
        # Or create symlinks into the same lib base dir as where the srcs are stored in bin
        src = srcs[i]
        o_file = compiled_output_files[i]

        if src_map[src]["lib_name"] == lib:
            sym_path = working_dir
        else:
            sym_path = build_path("bin", top_ent_file, src_map[src]["lib_name"])

        symlinked_o_files.append(create_sym_link(ctx, o_file, o_file.basename, sym_path))
        _elaboration_sym_srcs.append(create_sym_link(ctx, src, src.path, sym_path))


    for name, t_dep in p_deps.items():
        if name != lib:
            lib_working_dir = build_path("bin", top_ent_file, name)
            sym_cf_files.append(create_sym_link(ctx, t_dep, t_dep.basename, lib_working_dir))

    elaboration_artifact_name, elaboration_artifact = get_elaboration_artifact(ctx, working_dir)
    curr_lib_file = lib_cfg_map[lib]

    args = ctx.actions.args()
    new_lib_file = _prepare_cfg_file_content(
        ctx,
        args,
        working_dir,
        lib_name,
        curr_lib_file,
    )

    elab = "-e"
    add_no_run = False
    if ctx.attr.elab_flags or ctx.attr.generics:
        elab = "--elab-run"
        add_no_run = True

    rel_path = get_execroot_workdir_rel_path(new_lib_file)
    length = len(new_lib_file.dirname.split('/'))
    args.add("./{}{}".format(rel_path, ghdl_compiler.path))
    args.add(elab)
    args.add("-o {}".format(elaboration_artifact_name))
    args.add("--std=08")
    args.add("--ieee=synopsys --warn-no-vital-generic")
    args.add("--work={}".format(lib_name))
    args.add_all(sym_cf_files, format_each="-P" + "../" * length + "%s", map_each=get_dir)

    args.add(ctx.attr.entity_name)
    if ctx.attr.arch:
        args.add(ctx.attr.arch)
    for generic in ctx.attr.generics:
      args.add(generic)
    if add_no_run:
      args.add("--no-run")

    files_to_link = []
    files_to_link.extend(compiled_output_files)
    files_to_link.extend(symlinked_o_files)

    src_files = []
    src_files.extend(srcs)
    src_files.extend(_elaboration_sym_srcs)

    ctx.actions.run(
        mnemonic = "ghdlElaboration",
        executable = ghdl_tool.path,
        tools = [ghdl_tool, ghdl_compiler] + ghdl_compiler_deps,
        arguments = [args],
        env = {"DOCKER_IMAGE": docker, "HOME": "/", "CC": c_compiler, "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"},
        inputs = [curr_lib_file] + files_to_link + src_files + lib_cfg_map.values() + sym_cf_files,
        outputs = [new_lib_file, elaboration_artifact],
    )

    return elaboration_artifact


def _ghdl_elaboration_impl(ctx):
    # Tooling
    info = ctx.toolchains["@rules_ghdl//:ghdl_toolchain_type"].ghdlinfo

    srcs = get_srcs(ctx)
    src_map = build_source_map(ctx.attr.deps)

    lib_cfg_map = {}
    compiled_output_files = []
    compiled_srcs = []

    for src in srcs:
        o_file = _ghdl_analysis(
            ctx,
            info,
            src,
            src_map,
            lib_cfg_map,
            compiled_output_files,
            compiled_srcs)
        compiled_output_files.append(o_file)
        compiled_srcs.append(src)

    elaboration_artifact = _ghdl_elaboration(ctx, info, srcs, src, src_map, lib_cfg_map, compiled_output_files)

    return [
        DefaultInfo(files = depset([elaboration_artifact])),
        GHDLFiles(transitive_sources=srcs, outs=[elaboration_artifact])
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
ghdl_elaboration = rule(
    implementation = _ghdl_elaboration_impl,
    attrs = {
        "entity_name": attr.string(mandatory=True),
        "arch": attr.string(mandatory=False),
        # TODO: Remove sources from testbench rule
        "srcs": attr.label(allow_single_file = [".vhd", ".v"], mandatory = True),
        "deps": attr.label_list(),

        "elab_flags" : attr.string_list(mandatory=False, allow_empty=True),
        "generics" : attr.string_list(mandatory=False, allow_empty=True), # Should be dict

    },
    toolchains = ["@rules_ghdl//:ghdl_toolchain_type"]
)
