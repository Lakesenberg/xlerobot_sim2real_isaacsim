#!/bin/bash
# Launch the real robot container on DGX Spark (ARM64 Blackwell)
# Includes ARM64-specific TLS fixes
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

xhost +

docker run -it --rm --name real-robot --network host --privileged --gpus all \
  -e DISPLAY \
  -e LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1 \
  -e GLIBC_TUNABLES=glibc.rtld.optional_static_tls=2048 \
  -v /dev:/dev \
  -v /run/udev:/run/udev:ro \
  -v "$HOME/.Xauthority:/root/.Xauthority" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "$HOME/.cache/huggingface/lerobot/calibration:/root/.cache/huggingface/lerobot/calibration" \
  -v "$SCRIPT_DIR/docker/env:/root/env" \
  -v "$HOME/sim2real/models:/workspace/models" \
  -v "$SCRIPT_DIR/docker/real/scripts:/workspace/Isaac-GR00T/gr00t/eval/real_robot/SO100" \
  real-robot \
  /bin/bash
