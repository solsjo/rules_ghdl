#!/bin/bash

set -e

lsb_release -a

read -a cmd_arr <<< $@
echo "firstr: $cmd_arr"
echo "hello3 ${cmd_arr[@]}"
ghdl_args="$@"

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

echo "first $ghdl_args"

echo "hello $cmd_arr"

echo "hello4 ${cmd_arr}"

echo "hello2 ${cmd_arr[@]}"
echo "pwd: $PWD"
ls -la
ls -la ./external/ghdl_toolchain/bin
#${cmd_arr}

./external/ghdl_toolchain/bin/ghdl -a

sh -c "$ghdl_args"

fi

exit $?
