#!/bin/bash
# Build both Docker images for GR00T N1.7 + DGX Spark (ARM64 Blackwell)
# Isaac Lab 3.0.0-beta1 / Isaac Sim 6 beta / LeRobot 0.5.2+ / Python 3.12
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building Simulation Container (N1.7 + ARM64) ==="
echo "    Base: nvcr.io/nvidia/isaac-lab:3.0.0-beta1"
echo "    LeRobot: d656da8 (0.5.2+)"
echo ""
docker build -t teleop-docker:n17 -f docker/sim/Dockerfile.n17.arm64 .

echo ""
echo "=== Building Real Robot Container (N1.7 + ARM64 Blackwell) ==="
echo "    Base: nvidia/cuda:13.2.2-devel-ubuntu24.04"
echo "    GR00T: 4b1dca9 (N1.7)"
echo "    Python: 3.12"
echo ""
docker build -t real-robot:n17 -f docker/real/Dockerfile.n17.blackwell.arm64 .

echo ""
echo "=== Build Complete ==="
echo "Run simulation:  ./run_teleop_n17_arm64.sh"
echo "Run real robot:  ./run_real_robot_n17_arm64.sh"
