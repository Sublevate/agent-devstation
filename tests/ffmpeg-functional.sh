#!/usr/bin/env bash
set -euo pipefail

workdir=$(mktemp -d)
trap 'rm -rf -- "$workdir"' EXIT
output="$workdir/agent-devstation.mp4"

ffmpeg -hide_banner -loglevel error \
  -f lavfi -i testsrc2=size=128x72:rate=10 \
  -f lavfi -i sine=frequency=1000:sample_rate=48000 \
  -t 1 -c:v libx264 -pix_fmt yuv420p -c:a aac \
  -movflags +faststart -y "$output"

test "$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$output")" = h264
test "$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$output")" = aac
format=$(ffprobe -v error -show_entries format=format_name -of default=nw=1:nk=1 "$output")
[[ ",$format," == *,mp4,* ]]
ffmpeg -hide_banner -loglevel error -i "$output" -f null -
