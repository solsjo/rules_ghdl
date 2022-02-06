#!/bin/bash

set -e

old_lib_file=${1}
new_lib_file=${2}
work_dir=${3}
ghdl_bin=${4}
shift 4
echo "first>>>>>>>>>>>>>>>>>>>>>"
ghdl_args="$@"

readarray -t ghdl_args < <("$@")
echo "cmds::: ${ghdl_args[@]}"
#./external/ghdl_toolchain/bin/ghdl --version
echo "****"

if [ -n "$old_lib_file" ]; then
  echo "copying $old_lib_file"
  cp "$old_lib_file" "$new_lib_file"
  ls -la "$new_lib_file"
fi

cd "$work_dir"

if [ -n "$DOCKER_IMAGE" ]; then
# regex explaination, we want to extract the output base
# the output base usually ends with
# _bazel_<user name>/<MD5 of workspace directory>
output_base_path=$(readlink -f $(pwd) | \
                   grep -Eow .*/_bazel_[^/]*/[0-9a-zA-Z]*)

docker run --rm -t \
  --user "$(id -u):$(id -g)" \
  --volume $output_base_path:$output_base_path \
  --workdir "$PWD" \
  "$DOCKER_IMAGE" sh -c "$ghdl_args"
else
ls "$ghdl_bin"
echo "::::::::::"
"$ghdl_bin" "${ghdl_args[@]}"

fi

exit $?
