#!/bin/bash

lines_src=$(cat src/* 2>/dev/null | wc -l)
lines_utils=$(cat src/utils/* 2>/dev/null | wc -l)

total_lines=$((lines_src + lines_utils))

echo "In src: $lines_src"
echo "In utils: $lines_utils"
echo "Total Lines: $total_lines"

