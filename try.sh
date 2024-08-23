#!/bin/sh

set -e

zig build-exe main.zig
exec ./main

