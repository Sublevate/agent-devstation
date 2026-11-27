#!/usr/bin/env bash
set -euo pipefail

enabled=${AGENT_DEVSTATION_FFMPEG_ENABLED-false}

case "$enabled" in
  true|false) ;;
  *) echo 'AGENT_DEVSTATION_FFMPEG_ENABLED must be true or false' >&2; exit 2 ;;
esac

package_installed() {
  [[ "$(dpkg-query -W -f='${db:Status-Status}' ffmpeg 2>/dev/null || true)" == installed ]]
}

has_mp4_support() {
  command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null || return 1

  local output video_codec audio_codec status=0
  output=$(mktemp --suffix=.mp4)
  if ! ffmpeg -hide_banner -loglevel error \
    -f lavfi -i testsrc2=size=64x64:rate=5 \
    -f lavfi -i sine=frequency=1000:sample_rate=48000 \
    -t 0.4 -c:v libx264 -pix_fmt yuv420p -c:a aac \
    -movflags +faststart -y "$output"; then
    status=1
  fi
  if [[ "$status" == 0 ]]; then
    video_codec=$(ffprobe -v error -select_streams v:0 \
      -show_entries stream=codec_name -of default=nw=1:nk=1 "$output") || status=1
    audio_codec=$(ffprobe -v error -select_streams a:0 \
      -show_entries stream=codec_name -of default=nw=1:nk=1 "$output") || status=1
    [[ "$video_codec" == h264 && "$audio_codec" == aac ]] || status=1
  fi
  rm -f -- "$output"
  return "$status"
}

if [[ "$enabled" == false ]]; then
  if package_installed; then
    echo 'Uninstalling FFmpeg (disabled)'
    DEBIAN_FRONTEND=noninteractive apt-get remove -y ffmpeg
    rm -rf /var/lib/apt/lists/*
  else
    echo 'FFmpeg disabled; not installed'
  fi
  exit 0
fi

if package_installed && has_mp4_support; then
  version=$(dpkg-query -W -f='${Version}' ffmpeg)
  echo "Found FFmpeg $version with H.264/AAC MP4 support; already installed"
  exit 0
fi

echo 'Installing FFmpeg with H.264/AAC MP4 support'
# A stop during an APT operation can leave dpkg configuration unfinished.
# Resume it before asking APT to install or repair FFmpeg.
if ! dpkg --configure -a; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-broken --no-remove --no-install-recommends
fi
apt-get update
if package_installed; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y --reinstall --no-install-recommends ffmpeg
else
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ffmpeg
fi
rm -rf /var/lib/apt/lists/*

has_mp4_support || {
  echo 'FFmpeg installation cannot encode and inspect an H.264/AAC MP4 file' >&2
  exit 1
}
version=$(dpkg-query -W -f='${Version}' ffmpeg)
echo "FFmpeg $version with H.264/AAC MP4 support ready"
