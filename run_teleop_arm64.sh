#!/bin/bash
# Launch the simulation container on DGX Spark (ARM64 Blackwell)
# Includes all ARM64-specific fixes: TLS preload, GLIBC tunables
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

xhost +

docker run --name teleop -it --privileged --gpus all \
  -e "ACCEPT_EULA=Y" \
  -e "PRIVACY_CONSENT=Y" \
  -e DISPLAY \
  -e LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1 \
  -e GLIBC_TUNABLES=glibc.rtld.optional_static_tls=2048 \
  --rm --network=host \
  -v /dev:/dev \
  -v /run/udev:/run/udev:ro \
  -v "$HOME/.Xauthority:/root/.Xauthority" \
  -v "$HOME/docker/isaac-sim/cache/kit:/isaac-sim/kit/cache:rw" \
  -v "$HOME/docker/isaac-sim/cache/ov:/root/.cache/ov:rw" \
  -v "$HOME/docker/isaac-sim/cache/pip:/root/.cache/pip:rw" \
  -v "$HOME/docker/isaac-sim/cache/glcache:/root/.cache/nvidia/GLCache:rw" \
  -v "$HOME/docker/isaac-sim/cache/computecache:/root/.nv/ComputeCache:rw" \
  -v "$HOME/docker/isaac-sim/logs:/root/.nvidia-omniverse/logs:rw" \
  -v "$HOME/docker/isaac-sim/data:/root/.local/share/ov/data:rw" \
  -v "$HOME/docker/isaac-sim/documents:/root/Documents:rw" \
  -v "$HOME/.cache/huggingface/lerobot/calibration:/root/.cache/huggingface/lerobot/calibration" \
  -v "$SCRIPT_DIR/docker/env:/root/env" \
  -v "$SCRIPT_DIR/source:/workspace/Sim-to-Real-SO-101-Workshop/source" \
  -v "$SCRIPT_DIR/outputs:/workspace/Sim-to-Real-SO-101-Workshop/outputs" \
  -v "$SCRIPT_DIR/datasets:/workspace/Sim-to-Real-SO-101-Workshop/datasets" \
  teleop-docker:latest
