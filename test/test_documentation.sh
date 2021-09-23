#!/bin/sh

# Execute all commands in README, we want the docuemntation to be up to
# date, don't we.
# Call from repo root
cat README.md | grep -e "$ bazelisk.*" | sed 's/$ //g' | sh
