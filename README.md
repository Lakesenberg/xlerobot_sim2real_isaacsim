# XLeRobot Sim-to-Real on NVIDIA DGX Spark (ARM64 Blackwell)

![XLeRobot Isaac Sim + LeRobot](isaac%20sim%20lerobot.gif)

XLeRobot IsaacLab extension + Sim-to-Real SO-101 Workshop, adapted for **NVIDIA DGX Spark (GB10)** ARM64 Blackwell platform with GROOT N1.6.

This repository provides a complete sim-to-real pipeline: simulate robotic manipulation in Isaac Sim, collect teleoperation data, train policies with LeRobot/GR00T, and deploy to real SO-101 hardware — all running natively on DGX Spark aarch64.

---

## Table of Contents

- [Platform](#platform)
- [Architecture Overview](#architecture-overview)
- [ARM64 Fixes Summary](#arm64-fixes-summary)
- [Quick Start](#quick-start)
  - [1. Clone & Prepare](#1-clone--prepare)
  - [2. Build Simulation Container (ARM64)](#2-build-simulation-container-arm64)
  - [3. Build Real Robot Container (ARM64)](#3-build-real-robot-container-arm64)
  - [4. Launch Simulation](#4-launch-simulation)
  - [5. Teleoperation & Data Collection](#5-teleoperation--data-collection)
  - [6. Train Policy with GR00T N1.6](#6-train-policy-with-groot-n16)
  - [7. Deploy to Real SO-101](#7-deploy-to-real-so-101)
- [XLeRobot Environments](#xlerobot-environments)
- [SO-101 Workshop Tasks](#so-101-workshop-tasks)
- [Full Workflow Scripts](#full-workflow-scripts)
- [Teleoperation Controls](#teleoperation-controls)
- [ARM64 Fixes — Detailed](#arm64-fixes--detailed)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)
- [License](#license)

---

## Platform

| Component | Specification |
|---|---|
| Hardware | NVIDIA DGX Spark (GB10) |
| Architecture | aarch64 (ARM64) |
| GPU | NVIDIA Blackwell, ~92 GB unified memory |
| OS | Ubuntu 24.04.2 LTS |
| Kernel | 6.17.0-1008-nvidia |
| CUDA | 13.0 |
| Driver | 580.126.09 |
| Isaac Sim | 4.5+ (via Isaac Lab 2.3.2 container) |
| GR00T | N1.6 |
| Python | 3.10 (required by GR00T) |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    DGX Spark (GB10 ARM64)                       │
│                                                                 │
│  ┌──────────────────────┐    ┌──────────────────────────────┐   │
│  │  Sim Container       │    │  Real Robot Container        │   │
│  │  (teleop-docker)     │    │  (real-robot)                │   │
│  │                      │    │                              │   │
│  │  Isaac Sim 4.5+      │    │  GR00T N1.6 Policy Server   │   │
│  │  Isaac Lab 2.3.2     │    │  SO-101 Hardware Control     │   │
│  │  LeRobot             │    │  Feetech Servo SDK           │   │
│  │  XLeRobot Extension  │    │  Rerun Visualization         │   │
│  │  SO-101 Tasks        │    │                              │   │
│  │                      │    │                              │   │
│  │  Teleoperation ──────┼────┼─▶ Policy Inference           │   │
│  │  Data Recording      │    │   Action Execution           │   │
│  │  Policy Evaluation   │    │   Camera Feedback             │   │
│  └──────────────────────┘    └──────────────────────────────┘   │
│           │                              │                      │
│           ▼                              ▼                      │
│    HuggingFace Hub               Real SO-101 Robot             │
│    (Datasets & Models)           (USB Serial + Cameras)         │
└─────────────────────────────────────────────────────────────────┘
```

**Pipeline:**
1. **Simulate** — Isaac Sim + IsaacLab environments for SO-101 / XLeRobot
2. **Collect** — Keyboard/gamepad teleoperation with LeRobot recording
3. **Train** — GR00T N1.6 vision-language-action model fine-tuning
4. **Deploy** — Transfer trained policy to real SO-101 robot hardware

---

## Fixes Summary

This repository applies **ARM64 platform fixes** and **Python packaging fixes** to make the workshop run correctly on DGX Spark.

### ARM64 Platform Fixes

| # | Issue | Root Cause | Fix |
|---|---|---|---|
| 1 | `torchcodec` version not found | ARM64 PyPI skips 0.2–0.5 | Pin `>=0.11.0,<0.12.0` |
| 2 | CUDA PyTorch silently replaced by CPU | `torch==2.7.0` resolves to CPU wheel on aarch64 | Capture pre-installed version from base image |
| 3 | `triton==3.3.1` not found | ARM64 Triton starts at later versions | Strip from pyproject.toml |
| 4 | `libgomp.so.1: cannot allocate memory in static TLS block` | ARM64 static TLS region too small for Isaac Sim | `LD_PRELOAD` + `GLIBC_TUNABLES` |
| 5 | FFmpeg architecture mismatch | Original downloads x86_64 binary | Use `linuxarm64` build |
| 6 | GR00T requires Python 3.10 + hidden wheel | `torchcodec==0.10.0a0` not on PyPI for ARM64 | Install bundled wheel from `scripts/deployment/dgpu/wheels/` |

### Python Packaging Fixes

| # | Issue | Root Cause | Fix |
|---|---|---|---|
| 7 | `ImportError: xlerobot_tasks.assets.xlerobot` | `assets/` module missing entirely | Created `xlerobot.py` (XLEROBOT_CFG) and `scenes.py` (TABLE_WITH_CUBE_CFG, LOFT_CFG) |
| 8 | Subpackages not installed | `setup.py` hardcoded `packages=["xlerobot_tasks"]` | Changed to `find_packages()` (discovers all 7 subpackages) |
| 9 | `sim_to_real_so101` not found as package | Missing `__init__.py` at package root | Created `__init__.py` |
| 10 | Entry points fail (`list_envs`, etc.) | `scripts/` missing `__init__.py` | Created `scripts/__init__.py` |
| 11 | `requires-python >= 3.11` blocks Python 3.10 | GR00T needs 3.10 | Changed to `>= 3.10` |
| 12 | XLeRobot assets not found in container | No mount or env var for USD assets | Added `-v` mount + `XLEROBOT_ASSETS_ROOT` env var |

---

## Quick Start

### 1. Clone & Prepare

```bash
# Clone this repository
cd ~
git clone <this-repo-url> xlerobot-sim2real
cd ~/xlerobot-sim2real

# Create Isaac Sim cache directories
mkdir -p ~/docker/isaac-sim/cache/{kit,ov,pip,glcache,computecache}
mkdir -p ~/docker/isaac-sim/{logs,data,documents}
mkdir -p ~/xlerobot-sim2real/{outputs,datasets}
```

### 2. Build Simulation Container (ARM64)

The Dockerfile has been patched for ARM64 compatibility.

```bash
cd ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main
docker build -t teleop-docker -f docker/sim/Dockerfile.arm64 .
```

If `Dockerfile.arm64` does not exist yet, apply the fixes to the original Dockerfile:

```bash
# Apply ARM64 patches to sim Dockerfile
cd ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main
cp docker/sim/Dockerfile docker/sim/Dockerfile.arm64
```

Then edit `docker/sim/Dockerfile.arm64` with these changes:

```dockerfile
# FIX 1: torchcodec version range for ARM64
# BEFORE: "torchcodec>=0.2.1,<0.6.0"
# AFTER:
    "torchcodec>=0.11.0,<0.12.0" \

# FIX 2: Preserve CUDA PyTorch from base image (don't let pip replace with CPU wheel)
# BEFORE:
#   "torch==2.7.0" \
#   "torchvision==0.22.0" \
# AFTER:
RUN printf '%s\n' \
    "packaging==23.0" \
    "numpy==1.26.0" \
    "lxml==4.9.4" \
    "torch==$($PYTHON -c 'import torch; print(torch.__version__)')" \
    "torchvision==$($PYTHON -c 'import torchvision; print(torchvision.__version__)')" \
    "imageio==2.37.0" \
    > /tmp/constraints.txt

# FIX 1 (FFmpeg): Use ARM64 FFmpeg build
# BEFORE: ffmpeg-n7.1-latest-linux64-lgpl-shared-7.1.tar.xz
# AFTER:  ffmpeg-n7.1-latest-linuxarm64-lgpl-shared-7.1.tar.xz
RUN curl --proto "=https" --tlsv1.2 -sSf -L -o /tmp/ffmpeg.tar.xz \
    https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n7.1-latest-linuxarm64-lgpl-shared-7.1.tar.xz && \
    tar -xf /tmp/ffmpeg.tar.xz -C /usr/local --strip-components=1 && \
    ldconfig && \
    rm /tmp/ffmpeg.tar.xz
```

Build:
```bash
docker build -t teleop-docker -f docker/sim/Dockerfile.arm64 .
```

### 3. Build Real Robot Container (ARM64)

```bash
cd ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main

# FIX 3: Add triton removal to Blackwell Dockerfile
# In docker/real/Dockerfile.blackwell, after the flash-attn sed line, add:
#   sed -i '/triton==3.3.1/d' pyproject.toml && \

./docker/real/build.sh blackwell
```

### 4. Launch Simulation

Use the one-liner script (recommended):

```bash
cd ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main
./run_teleop_arm64.sh
```

Or run manually with full control:

```bash
cd ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main
PROJECT_ROOT="$(cd .. && pwd)"

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
  -v "$(pwd)/docker/env:/root/env" \
  -v "$(pwd)/source:/workspace/Sim-to-Real-SO-101-Workshop/source" \
  -v "$(pwd)/outputs:/workspace/Sim-to-Real-SO-101-Workshop/outputs" \
  -v "$(pwd)/datasets:/workspace/Sim-to-Real-SO-101-Workshop/datasets" \
  -v "$PROJECT_ROOT/source/xlerobot_tasks:/workspace/xlerobot_tasks" \
  -v "$PROJECT_ROOT/assets:/workspace/xlerobot_assets" \
  -e XLEROBOT_ASSETS_ROOT=/workspace/xlerobot_assets \
  teleop-docker:latest
```

The container entrypoint automatically installs both `sim_to_real_so101` and `xlerobot_tasks` (if mounted) via `pip install -e`.

Verify inside the container:

```bash
# Check CUDA is available (should NOT be CPU-only)
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}, Device: {torch.cuda.get_device_name(0)}')"

# List available environments
list_envs
```

### 5. Teleoperation & Data Collection

Inside the simulation container:

```bash
# === SO-101 Tasks (single arm, vial-to-rack) ===

# Test environment with zero actions
zero_agent --task Lerobot-So101-Teleop-Vials-To-Rack --num_envs 1 --enable_cameras

# Teleoperate and record data
lerobot_agent \
  --task Lerobot-So101-Teleop-Vials-To-Rack \
  --num_envs 1 \
  --enable_cameras \
  --repo_id <your-hf-username>/so101-vials-sim

# With domain randomization (recommended for sim-to-real)
lerobot_agent \
  --task Lerobot-So101-Teleop-Vials-To-Rack-DR \
  --num_envs 1 \
  --enable_cameras \
  --repo_id <your-hf-username>/so101-vials-sim-dr

# === XLeRobot Tasks (dual arm, mobile manipulator) ===

# Keyboard teleoperation
python scripts/teleop_xlerobot.py --enable_cameras --num_envs 1 --task XLeRobot-v0

# Cube lifting task
python scripts/teleop_xlerobot.py --enable_cameras --num_envs 1 --task XLeRobot-LiftCube-v0

# Xbox gamepad
python scripts/teleop_xlerobot.py --enable_cameras --num_envs 1 --task XLeRobot-v0 --teleop_device xlerobot-gamepad
```

Push recorded dataset to HuggingFace:

```bash
lerobot_push_dataset --repo_id <your-hf-username>/so101-vials-sim-dr
```

### 6. Train Policy with GR00T N1.6

On DGX Spark (host or in a conda env):

```bash
# FIX 6: GR00T requires Python 3.10
conda create -n gr00t python=3.10 -y
conda activate gr00t

# Clone GR00T
git clone https://github.com/NVIDIA/Isaac-GR00T.git
cd Isaac-GR00T

# Install bundled ARM64 torchcodec wheel (not available on PyPI for aarch64)
pip install scripts/deployment/dgpu/wheels/torchcodec-0.10.0a0-cp310-cp310-linux_aarch64.whl

# Install GR00T
pip install -e .

# Fine-tune GR00T N1.6 on your collected dataset
python scripts/train.py \
  --dataset_repo_id <your-hf-username>/so101-vials-sim-dr \
  --num_epochs 50 \
  --batch_size 32 \
  --output_dir ~/sim2real/models/groot-so101-vials
```

### 7. Deploy to Real SO-101

```bash
# Start Real Robot container
cd ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main

docker run -it --rm --name real-robot --network host --privileged --gpus all \
  -e DISPLAY \
  -e LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1 \
  -e GLIBC_TUNABLES=glibc.rtld.optional_static_tls=2048 \
  -v /dev:/dev \
  -v /run/udev:/run/udev:ro \
  -v "$HOME/.Xauthority:/root/.Xauthority" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "$HOME/.cache/huggingface/lerobot/calibration:/root/.cache/huggingface/lerobot/calibration" \
  -v "$(pwd)/docker/env:/root/env" \
  -v "$HOME/sim2real/models:/workspace/models" \
  -v "$(pwd)/docker/real/scripts:/workspace/Isaac-GR00T/gr00t/eval/real_robot/SO100" \
  real-robot \
  /bin/bash
```

Inside the real robot container:

```bash
# Step 1: Calibrate robot
cd /workspace/Isaac-GR00T/gr00t/eval/real_robot/SO100
python so101_control.py --port /dev/ttyACM0 --id my_robot --calibrate

# Step 2: Verify calibration
python so101_check_calibration.py --id my_robot

# Step 3: Test manual control
python so101_manual_control.py --port /dev/ttyACM0 --id my_robot

# Step 4: Start GR00T policy server (terminal 1)
cd /Isaac-GR00T
python scripts/serve.py --model_path /workspace/models/groot-so101-vials

# Step 5: Run evaluation on real robot (terminal 2)
cd /workspace/Isaac-GR00T/gr00t/eval/real_robot/SO100
python so101_eval.py \
  --robot_port /dev/ttyACM0 \
  --robot_id my_robot \
  --server_url tcp://localhost:5555 \
  --task "pick up the vial and place it in the yellow rack"
```

---

## XLeRobot Environments

| Environment | Description | Robot |
|---|---|---|
| `XLeRobot-v0` | Default ground plane | Dual-arm mobile manipulator (17 DOF) |
| `XLeRobot-LiftCube-v0` | Cube lifting task | Dual-arm mobile manipulator |
| `XLeRobot-Loft-v0` | Loft scene environment | Dual-arm mobile manipulator |

## SO-101 Workshop Tasks

| Task | Description | Robot |
|---|---|---|
| `Lerobot-So101-Teleop-Base` | Debug: basic teleop | SO-101 (6 DOF + gripper) |
| `Lerobot-So101-Teleop-Task` | Debug: lightbox + cameras | SO-101 |
| `Lerobot-So101-Teleop-Vials-To-Rack` | Main: pick vial, place in rack | SO-101 |
| `Lerobot-So101-Teleop-Vials-To-Rack-DR` | Main + domain randomization | SO-101 |
| `Lerobot-So101-Teleop-Vials-To-Rack-Eval` | Evaluation (fixed appearance) | SO-101 |
| `Lerobot-So101-Teleop-Vials-To-Rack-DR-Eval` | Evaluation + DR | SO-101 |

---

## Full Workflow Scripts

| Command | Description |
|---|---|
| `list_envs` | List all registered environments |
| `zero_agent` | Run environment with zero actions (debug) |
| `random_agent` | Run environment with random actions (debug) |
| `lerobot_agent` | Teleoperate and record dataset |
| `lerobot_eval` | Evaluate trained policy in simulation |
| `lerobot_push_dataset` | Upload dataset to HuggingFace Hub |

---

## Teleoperation Controls

### SO-101 Keyboard (lerobot_agent)

| Key | Action |
|---|---|
| W / S | Forward / Backward |
| A / D | Left / Right |
| Q / E | Up / Down |
| U / O | Gripper open / close |
| B | Start recording |
| R | Reset (failure) |
| N | Mark success & reset |

### XLeRobot Keyboard (teleop_xlerobot.py)

| Key | Action |
|---|---|
| W/S, A/D, Q/E | Right arm IK (translate) |
| J/L, K/I | Right arm IK (rotate) |
| U / O | Right gripper |
| SHIFT + above | Left arm |
| 7/9, 8/0 | Head pan / tilt |
| Arrow keys | Base translate |
| Z / X | Base rotate |
| 1 / 2 / 3 | Base speed level |
| B | Start |
| R | Reset |
| N | Success |

### XLeRobot Xbox Gamepad

| Input | Action |
|---|---|
| Left Stick | Arm translate XY |
| Right Stick | Arm up/down + yaw |
| D-pad Up/Down | Arm pitch |
| RT / RB | Gripper |
| LB (hold) | Switch to left arm |
| D-pad L/R | Head pan |
| LT (analog) | Head tilt |

---

## Fixes — Detailed

### ARM64 Fix 1: torchcodec Versions Don't Exist on ARM64

On aarch64, PyPI has no `torchcodec` between 0.0.x and 0.11.x.

```dockerfile
# BEFORE
"torchcodec>=0.2.1,<0.6.0"

# AFTER
"torchcodec>=0.11.0,<0.12.0"
```

### ARM64 Fix 2: pip Silently Replaces CUDA PyTorch with CPU

On ARM64, `torch==2.7.0` resolves to a CPU-only wheel. The base container already has a CUDA-enabled build from NVIDIA. Capture it dynamically:

```dockerfile
# BEFORE
"torch==2.7.0" \
"torchvision==0.22.0" \

# AFTER — preserve NVIDIA's CUDA build
"torch==$($PYTHON -c 'import torch; print(torch.__version__)')" \
"torchvision==$($PYTHON -c 'import torchvision; print(torchvision.__version__)')" \
```

### ARM64 Fix 3: triton==3.3.1 Missing on ARM64

```dockerfile
# Add after the flash-attn sed line
sed -i '/triton==3.3.1/d' pyproject.toml && \
```

### ARM64 Fix 4: Static TLS Exhaustion on ARM64

Isaac Sim loads hundreds of shared libraries. ARM64 has smaller default static TLS allocation than x86_64.

```bash
# Add these to docker run
-e LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1
-e GLIBC_TUNABLES=glibc.rtld.optional_static_tls=2048
```

| Variable | Purpose |
|---|---|
| `LD_PRELOAD` | Load libgomp first, ensuring TLS slot allocation |
| `GLIBC_TUNABLES` | Expand static TLS region to 2048 bytes |

### ARM64 Fix 5: FFmpeg Build Architecture

The original Dockerfile downloads x86_64 FFmpeg. Use the ARM64 build:

```dockerfile
# BEFORE
ffmpeg-n7.1-latest-linux64-lgpl-shared-7.1.tar.xz

# AFTER
ffmpeg-n7.1-latest-linuxarm64-lgpl-shared-7.1.tar.xz
```

### ARM64 Fix 6: GR00T Requires Python 3.10 + Hidden Wheel

DGX Spark ships Python 3.13. GR00T needs 3.10. Additionally, `torchcodec==0.10.0a0` is not on PyPI for ARM64 but ships inside the GR00T repo:

```bash
conda create -n gr00t python=3.10 -y
conda activate gr00t
cd Isaac-GR00T
pip install scripts/deployment/dgpu/wheels/torchcodec-0.10.0a0-cp310-cp310-linux_aarch64.whl
pip install -e .
```

### Packaging Fix 7: xlerobot_tasks Missing Asset Modules

The original repo was missing the entire `xlerobot_tasks/assets/` Python module. Every environment config imported from it:

```python
from xlerobot_tasks.assets.xlerobot import XLEROBOT_CFG   # did not exist
from xlerobot_tasks.assets.scenes import TABLE_WITH_CUBE_CFG  # did not exist
```

Created three files:
- `assets/__init__.py`
- `assets/xlerobot.py` — defines `XLEROBOT_CFG` (ArticulationCfg referencing `assets/robots/xlerobot/xlerobot.usd`)
- `assets/scenes.py` — defines `TABLE_WITH_CUBE_CFG`, `LOFT_CFG` (referencing scene USD files)

### Packaging Fix 8: setup.py Only Declared Top-Level Package

```python
# BEFORE — only installs xlerobot_tasks/, misses devices/, utils/, tasks/, assets/
packages=["xlerobot_tasks"]

# AFTER — auto-discovers all 7 subpackages
packages=find_packages()
```

### Packaging Fix 9–10: sim_to_real_so101 Missing `__init__.py`

- Created `sim_to_real_so101/__init__.py` — without it, `find_packages(where="..")` could not discover the package
- Created `sim_to_real_so101/scripts/__init__.py` — without it, entry points like `list_envs = "sim_to_real_so101.scripts.list_envs:main"` fail

### Packaging Fix 11: Python Version Constraint

```toml
# BEFORE
requires-python = ">=3.11"

# AFTER — GR00T needs 3.10
requires-python = ">=3.10"
```

### Packaging Fix 12: XLeRobot Assets Not Mounted in Container

The container entrypoint now auto-installs `xlerobot_tasks` if the mount is present. The launch script mounts both the source code and assets, and sets the `XLEROBOT_ASSETS_ROOT` environment variable:

```bash
-v "$PROJECT_ROOT/source/xlerobot_tasks:/workspace/xlerobot_tasks"
-v "$PROJECT_ROOT/assets:/workspace/xlerobot_assets"
-e XLEROBOT_ASSETS_ROOT=/workspace/xlerobot_assets
```

---

## Troubleshooting

### `cannot allocate memory in static TLS block`

You forgot the TLS environment variables. Add to your `docker run`:
```bash
-e LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1
-e GLIBC_TUNABLES=glibc.rtld.optional_static_tls=2048
```

### `torch.cuda.is_available()` returns `False`

pip replaced the CUDA PyTorch with a CPU-only wheel. Rebuild the container with Fix 2 (dynamic version capture).

### `No matching distribution found for torchcodec`

ARM64 package versions differ from x86_64. Use `torchcodec>=0.11.0,<0.12.0`.

### Empty `/workspace/Sim-to-Real-SO-101-Workshop/` inside container

Check your `-v` mount paths match where you actually cloned the repo. Use `$(pwd)` or absolute paths.

### `ModuleNotFoundError: No module named 'flash_attn'`

On ARM64 Blackwell, flash-attn needs to be built from source with `MAX_JOBS=2`:
```bash
export MAX_JOBS=2
pip install flash-attn --no-build-isolation --no-cache-dir
```

### GR00T install fails with Python 3.12+

GR00T requires Python 3.10. Use conda:
```bash
conda create -n gr00t python=3.10 -y
```

### `ImportError: No module named 'xlerobot_tasks.assets.xlerobot'`

The `assets/` module was missing in the original repo. This repository includes the fix. If you see this error, make sure you are using the patched version with `assets/xlerobot.py` and `assets/scenes.py`.

### `ModuleNotFoundError: No module named 'sim_to_real_so101'`

The package root was missing `__init__.py`. This repository includes the fix. Verify the file exists:
```bash
ls Sim-to-Real-SO-101-Workshop-main/source/sim_to_real_so101/__init__.py
```

### XLeRobot environments not registered / `import xlerobot_tasks` fails

Ensure the container mounts `xlerobot_tasks` and sets `XLEROBOT_ASSETS_ROOT`. Use `./run_teleop_arm64.sh` which does this automatically.

---

## Project Structure

```
xlerobot-sim2real/
├── README.md                          # English documentation
├── GUIDE_CN.md                        # Chinese step-by-step guide
├── isaac sim lerobot.gif              # Demo animation
├── assets/                            # XLeRobot robot & scene USD assets
│   ├── robots/xlerobot/               #   Robot USD models
│   └── scenes/                        #   Scene assets (table, cube, loft)
├── scripts/                           # XLeRobot teleoperation scripts
│   ├── teleop_xlerobot.py             #   Keyboard/gamepad teleop
│   ├── test_xlerobot_env.py           #   Environment test (random actions)
│   └── test_xlerobot_env_debug.py     #   Debug with verbose output
├── source/xlerobot_tasks/             # XLeRobot IsaacLab extension
│   ├── setup.py                       #   find_packages() auto-discovery
│   └── xlerobot_tasks/
│       ├── __init__.py                #   from .tasks import *
│       ├── assets/                    #   Robot & scene ArticulationCfg
│       │   ├── __init__.py
│       │   ├── xlerobot.py            #   XLEROBOT_CFG definition
│       │   └── scenes.py             #   TABLE_WITH_CUBE_CFG, LOFT_CFG
│       ├── devices/                   #   Input device drivers
│       ├── tasks/xlerobot/            #   Environment configs + MDP
│       └── utils/                     #   Constants, math, domain rand
├── docs/
│   └── DEVELOPMENT.md                 # Development timeline & architecture
└── Sim-to-Real-SO-101-Workshop-main/  # SO-101 Workshop (NVIDIA)
    ├── build_arm64.sh                 #   One-command build for ARM64
    ├── run_teleop_arm64.sh            #   Launch sim container (ARM64)
    ├── run_real_robot_arm64.sh        #   Launch real robot container (ARM64)
    ├── docker/
    │   ├── sim/
    │   │   ├── Dockerfile             #   Original sim Dockerfile (x86_64)
    │   │   ├── Dockerfile.arm64       #   ARM64-patched sim Dockerfile
    │   │   └── entrypoint.sh          #   Auto-installs both packages
    │   ├── real/
    │   │   ├── Dockerfile.blackwell       # Original Blackwell Dockerfile
    │   │   ├── Dockerfile.blackwell.arm64 # ARM64-patched Blackwell Dockerfile
    │   │   ├── Dockerfile.ada         #   Ada GPU Dockerfile
    │   │   └── scripts/               #   Robot control & calibration
    │   └── env                        #   Robot port configuration
    └── source/sim_to_real_so101/
        ├── __init__.py                #   Package root (was missing)
        ├── setup.py                   #   find_packages(where="..")
        ├── pyproject.toml             #   Entry points, requires-python>=3.10
        ├── scripts/                   #   lerobot_agent, eval, push
        │   └── __init__.py            #   (was missing, needed by entry points)
        ├── tasks/                     #   SO-101 environment configs
        ├── mdp/                       #   Observations, resets, terms
        ├── gr00t_client/              #   GR00T policy server client
        ├── utils/                     #   LeRobot interface & recorder
        └── assets/                    #   SO-101 USD + HDRI lighting
```

---

## License

Apache-2.0. See [LICENSE](Sim-to-Real-SO-101-Workshop-main/LICENSE).

XLeRobot IsaacLab extension and SO-101 Workshop source: NVIDIA CORPORATION & AFFILIATES.
ARM64 adaptation based on [Kabilankb's DGX Spark workshop guide](https://medium.com/@kabilankb2003).
