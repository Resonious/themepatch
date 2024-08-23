#!/bin/sh

set -e

zig build-exe main.zig
cp main ~/bin/themepatch-hx
