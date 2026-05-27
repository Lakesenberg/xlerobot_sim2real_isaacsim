#!/bin/bash
# Build both Docker images for DGX Spark (ARM64 Blackwell)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building Simulation Container (ARM64) ==="
docker build -t teleop-docker -f docker/sim/Dockerfile.arm64 .

echo ""
echo "=== Building Real Robot Container (ARM64 Blackwell) ==="
docker build -t real-robot -f docker/real/Dockerfile.blackwell.arm64 .

echo ""
echo "=== Build Complete ==="
echo "Run simulation:  ./run_teleop_arm64.sh"
echo "Run real robot:  ./run_real_robot_arm64.sh"
