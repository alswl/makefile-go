#!/usr/bin/env bash
# This script is used to bump the version of the operator.
# It uses semtag to bump the version.
#
# github.com/alswl/makefile-go
#
# Author: alswl
# Version: v0.2.1
#
# Usage: hack/bump.sh <stage> <scope> <dryrun>
# stage: final, alpha, beta, candidate
# scope: major, minor, patch, final
#
# 发版之前打 tag，会自动写入 VERSION 文件，并生成 tag
# 写入 VERSION 文件会强制带上 `-dev` 结尾，但是 push tag 则没有 -dev
# 因此，master 会触发包构建产生的镜像都有 -dev 结尾，而 tag push 产生的是明确的没有 -dev 的版本（尽管他们的 hash 一样）
# 即以 tag 作为明确版本发布信号

# cd root of the repo
pushd "$(dirname "$0")/.." > /dev/null

set -e

bump_stage=$1
bump_scope=$2
bump_dry_run=$3

if [ -z "$bump_stage" ]; then
  echo "bump stage is required"
  exit 1
fi
if [ -z "$bump_scope" ]; then
  echo "bump scope is required"
  exit 1
fi
if [ -z "$bump_dry_run" ]; then
  echo "bump dryrun is required"
  exit 1
fi

next=$(semtag "$bump_stage" -s "$bump_scope" -f -o)
echo "next version: $next"

# dry run
if [ "$bump_dry_run" = "true" ]; then
  echo "dryrun: true"
  exit 0
fi

# bump and tag
echo "dryrun: false"
# VERSION in file always has the -dev suffix
echo "${next}-dev" > VERSION
git add VERSION
git commit -m "chore: Bump version to $next"

# git tag did not contains dev suffix
semtag "$bump_stage" -s "$bump_scope"

popd > /dev/null
