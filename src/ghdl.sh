#!/bin/sh

set -e

# regex explaination, we want to extract the output base
# the output base usually ends with
# _bazel_<user name>/<MD5 of workspace directory>
output_base_path=$(readlink -f $(pwd) | \
                   grep -Eow .*/_bazel_[^/]*/[0-9a-zA-Z]*)
repo_name=$(basename $(readlink -f $(pwd)))
root=$(dirname \
       $(readlink -f $output_base_path/execroot/$repo_name/WORKSPACE))

ghdl_args="$@"

docker run --rm -t \
  --user "$(id -u):$(id -g)" \
  --volume $output_base_path:$output_base_path \
  --volume "$root":"$root" \
  --workdir "$PWD" \
  ghdl/vunit:llvm-master sh -c "$ghdl_args"

exit $?
