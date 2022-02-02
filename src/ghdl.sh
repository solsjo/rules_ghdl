#!/bin/sh

set -e

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
echo "$ghdl_args"
readarray -td, args <<<"$ghdl_args,"; unset 'a[-1]'; declare -p args;
echo "$args"
echo "${args[@]}"
"${args[@]}"
fi

exit $?
