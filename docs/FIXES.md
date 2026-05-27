# ARM64 & Packaging Fixes for DGX Spark

This document explains every fix applied to make the xlerobot + SO-101 workshop run on NVIDIA DGX Spark (GB10, ARM64 Blackwell).

Two sets of Dockerfiles are provided:

| Version | Sim Dockerfile | Real Dockerfile | Isaac Lab | GR00T | Python |
|---|---|---|---|---|---|
| **N1.7** (new) | `Dockerfile.n17.arm64` | `Dockerfile.n17.blackwell.arm64` | 3.0.0-beta1 | N1.7 | 3.12 |
| **N1.6** (stable) | `Dockerfile.arm64` | `Dockerfile.blackwell.arm64` | 2.3.2 | N1.6 | 3.10 |

N1.7 reference: [github.com/isaac-sim/Sim-to-Real-SO-101-Workshop/issues/1](https://github.com/isaac-sim/Sim-to-Real-SO-101-Workshop/issues/1) (johnnynunez)

All fixes are already applied in the repository. This file is for reference only.

---

## ARM64 Platform Fixes

### Fix 1: torchcodec Version Range (Dockerfile.arm64)

**Problem:** `No matching distribution found for torchcodec>=0.2.1,<0.6.0`

ARM64 PyPI skips torchcodec 0.2-0.5 entirely. The version history on aarch64 jumps from 0.0.x to 0.11.x.

```dockerfile
# BEFORE
"torchcodec>=0.2.1,<0.6.0"
# AFTER
"torchcodec>=0.11.0,<0.12.0"
```

### Fix 2: CUDA PyTorch Silently Replaced by CPU (Dockerfile.arm64)

**Problem:** `torch.cuda.is_available()` returns `False` after build

The Isaac Lab base image ships NVIDIA's CUDA-enabled PyTorch (`2.7.0a0+<hash>`). Pinning `torch==2.7.0` in constraints causes pip to find the CPU-only wheel on ARM64 PyPI — version "matches", so pip silently downgrades. No warnings.

```dockerfile
# BEFORE — resolves to CPU-only on aarch64
"torch==2.7.0"
"torchvision==0.22.0"

# AFTER — captures exact CUDA build from base image
"torch==$($PYTHON -c 'import torch; print(torch.__version__)')"
"torchvision==$($PYTHON -c 'import torchvision; print(torchvision.__version__)')"
```

### Fix 3: triton==3.3.1 Missing (Dockerfile.blackwell.arm64)

**Problem:** `No matching distribution found for triton==3.3.1`

ARM64 Triton packages start at later versions. Safe to remove because PyTorch nightly bundles Triton.

```dockerfile
sed -i '/triton==3.3.1/d' pyproject.toml
```

### Fix 4: Static TLS Exhaustion (run_teleop_arm64.sh)

**Problem:** `libgomp.so.1: cannot allocate memory in static TLS block`

ARM64's dynamic linker allocates a fixed-size static TLS region at process startup. Each shared library using thread-local variables consumes part of it. Isaac Sim loads hundreds of libraries (PyTorch, USD, PhysX, CUDA, OpenMP, Omniverse extensions), eventually exhausting the region. x86_64 has larger defaults so this rarely appears there.

```bash
-e LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1   # Load libgomp first for TLS slot
-e GLIBC_TUNABLES=glibc.rtld.optional_static_tls=2048    # Expand TLS region
```

### Fix 5: FFmpeg Architecture Mismatch (Dockerfile.arm64)

**Problem:** `Exec format error` on FFmpeg commands

Original Dockerfile downloads x86_64 FFmpeg binary.

```dockerfile
# BEFORE
ffmpeg-n7.1-latest-linux64-lgpl-shared-7.1.tar.xz
# AFTER
ffmpeg-n7.1-latest-linuxarm64-lgpl-shared-7.1.tar.xz
```

### Fix 6: GR00T Requires Python 3.10 + Hidden Wheel (Dockerfile.blackwell.arm64)

**Problem:** GR00T installation fails on Python 3.13 and `torchcodec==0.10.0a0` not found

DGX Spark ships Python 3.13. GR00T only supports 3.10. The required `torchcodec==0.10.0a0` is not on PyPI for ARM64, but a prebuilt wheel ships inside the GR00T repo at `scripts/deployment/dgpu/wheels/`.

```bash
conda create -n gr00t python=3.10 -y
pip install scripts/deployment/dgpu/wheels/torchcodec-0.10.0a0-cp310-cp310-linux_aarch64.whl
pip install -e .
```

---

## Python Packaging Fixes

### Fix 7: xlerobot_tasks Missing `assets/` Module

**Problem:** `ImportError: No module named 'xlerobot_tasks.assets.xlerobot'`

Three environment config files import from `xlerobot_tasks.assets`, but the module did not exist:
- `xlerobot_env_cfg.py:21` — `from xlerobot_tasks.assets.xlerobot import XLEROBOT_CFG`
- `xlerobot_lift_cube_env_cfg.py:8` — `from xlerobot_tasks.assets.scenes import TABLE_WITH_CUBE_CFG`
- `xlerobot_loft_env_cfg.py:3` — `from xlerobot_tasks.assets.scenes import LOFT_CFG`

**Fix:** Created three files:
- `xlerobot_tasks/assets/__init__.py`
- `xlerobot_tasks/assets/xlerobot.py` — `XLEROBOT_CFG` (ArticulationCfg for the 17-DOF dual-arm robot)
- `xlerobot_tasks/assets/scenes.py` — `TABLE_WITH_CUBE_CFG`, `LOFT_CFG` (AssetBaseCfg referencing scene USD)

### Fix 8: setup.py Hardcoded Package List

**Problem:** `import xlerobot_tasks.devices` fails after `pip install -e .`

`setup.py` declared `packages=["xlerobot_tasks"]` — only the top-level directory. Subpackages `devices/`, `utils/`, `tasks/`, `assets/` were not installed.

**Fix:** Changed to `packages=find_packages()`. Now discovers all 7 subpackages.

### Fix 9: sim_to_real_so101 Missing Root `__init__.py`

**Problem:** `ModuleNotFoundError: No module named 'sim_to_real_so101'`

`setup.py` uses `find_packages(where="..")` to find packages in the parent `source/` directory. But `source/sim_to_real_so101/` had no `__init__.py`, so Python did not recognize it as a package.

**Fix:** Created `source/sim_to_real_so101/__init__.py`.

### Fix 10: scripts/ Missing `__init__.py`

**Problem:** Entry points like `list_envs = "sim_to_real_so101.scripts.list_envs:main"` fail

`scripts/` was not a Python package (no `__init__.py`), so setuptools did not include it.

**Fix:** Created `source/sim_to_real_so101/scripts/__init__.py`.

### Fix 11: Python Version Constraint Too Strict

**Problem:** `pip install` rejects Python 3.10

`pyproject.toml` specified `requires-python = ">=3.11"`, but GR00T requires Python 3.10.

**Fix:** Changed to `requires-python = ">=3.10"`.

### Fix 12: XLeRobot Not Mounted in Container

**Problem:** `import xlerobot_tasks` fails inside Docker container

The original `docker run` command did not mount xlerobot_tasks source code or USD assets into the container.

**Fix:**
- `run_teleop_arm64.sh`: Added volume mounts for source and assets + `XLEROBOT_ASSETS_ROOT` env var
- `entrypoint.sh`: Added conditional `pip install -e /workspace/xlerobot_tasks/`
