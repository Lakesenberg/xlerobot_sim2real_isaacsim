# XLeRobot Sim-to-Real 全流程中文指南 (DGX Spark ARM64)

![XLeRobot Isaac Sim + LeRobot](isaac%20sim%20lerobot.gif)

> 本指南面向零基础用户，在 **NVIDIA DGX Spark (GB10)** 上从零搭建 XLeRobot / SO-101 机械臂的仿真到真机部署全流程。
> 每一行命令都有详细解释，照着做就行。

---

## 目录

- [你需要什么](#你需要什么)
- [整体流程一览](#整体流程一览)
- [第一步：准备工作](#第一步准备工作)
- [第二步：构建仿真容器](#第二步构建仿真容器)
- [第三步：构建真机容器](#第三步构建真机容器)
- [第四步：启动仿真环境](#第四步启动仿真环境)
- [第五步：验证环境](#第五步验证环境)
- [第六步：遥操作采集数据](#第六步遥操作采集数据)
- [第七步：上传数据集](#第七步上传数据集)
- [第八步：训练策略模型 (GR00T N1.6)](#第八步训练策略模型-groot-n16)
- [第九步：部署到真实 SO-101 机械臂](#第九步部署到真实-so-101-机械臂)
- [可用的仿真环境列表](#可用的仿真环境列表)
- [键盘操控说明](#键盘操控说明)
- [手柄操控说明](#手柄操控说明)
- [常见报错与解决](#常见报错与解决)
- [项目目录结构](#项目目录结构)

---

## 你需要什么

### 硬件

| 项目 | 要求 |
|---|---|
| 主机 | NVIDIA DGX Spark (GB10) |
| 架构 | aarch64 (ARM64) |
| GPU | Blackwell, ~92 GB 统一显存 |
| 真机 (可选) | SO-101 机械臂 + Feetech 舵机 + USB 摄像头 |

### 软件 (DGX Spark 上预装或需安装)

| 软件 | 版本 | 用途 |
|---|---|---|
| Ubuntu | 24.04 | 操作系统 |
| CUDA Toolkit | 13.0 | GPU 计算 |
| Docker | 最新 | 容器化运行环境 |
| NVIDIA Container Toolkit | 最新 | 让 Docker 能用 GPU |
| conda / miniforge | 最新 | Python 版本管理 (训练用) |

### 检查软件是否就绪

```bash
# 检查 Docker 是否安装
docker --version
# 期望输出: Docker version 2x.x.x

# 检查 NVIDIA Container Toolkit 是否正常
docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu24.04 nvidia-smi
# 期望输出: 看到 GPU 信息表格

# 检查架构 (必须是 aarch64)
uname -m
# 期望输出: aarch64
```

---

## 整体流程一览

```
第一步 准备工作        克隆代码、创建缓存目录
  |
第二步 构建仿真容器    docker build (Isaac Sim + LeRobot)
  |
第三步 构建真机容器    docker build (GR00T + 舵机控制)
  |
第四步 启动仿真环境    docker run (带 ARM64 修复参数)
  |
第五步 验证环境        检查 CUDA、列出可用任务
  |
第六步 遥操作采集数据  用键盘/手柄操控机械臂、录制数据集
  |
第七步 上传数据集      推送到 HuggingFace Hub
  |
第八步 训练策略模型    用 GR00T N1.6 微调视觉语言动作模型
  |
第九步 部署到真机      启动策略推理服务、连接真实 SO-101 执行
```

---

## 第一步：准备工作

> 所有 ARM64 兼容性修复和 Python 包结构修复已内置在本仓库的 Dockerfile 和代码中，直接照做即可。
> 技术细节见 Dockerfile 注释和 `README.md` 的 Fixes 章节。

### 1.1 克隆代码

```bash
cd ~
```
> 进入你的用户主目录 (Home)。

```bash
git clone <仓库地址> xlerobot-sim2real
```
> 把项目代码下载到 `~/xlerobot-sim2real` 文件夹。
> 把 `<仓库地址>` 替换成实际的 Git 仓库 URL。

```bash
cd ~/xlerobot-sim2real
```
> 进入项目根目录，后续所有操作都基于这个目录。

### 1.2 创建 Isaac Sim 缓存目录

```bash
mkdir -p ~/docker/isaac-sim/cache/kit
```
> 创建 Isaac Sim Kit 引擎的缓存目录。`-p` 表示如果父目录不存在就自动创建。

```bash
mkdir -p ~/docker/isaac-sim/cache/ov
```
> 创建 Omniverse 缓存目录。

```bash
mkdir -p ~/docker/isaac-sim/cache/pip
```
> 创建 pip 包缓存目录，避免每次启动容器都重新下载。

```bash
mkdir -p ~/docker/isaac-sim/cache/glcache
```
> 创建 OpenGL 着色器缓存目录。

```bash
mkdir -p ~/docker/isaac-sim/cache/computecache
```
> 创建 CUDA Compute 缓存目录。

```bash
mkdir -p ~/docker/isaac-sim/logs
```
> 创建日志存放目录。

```bash
mkdir -p ~/docker/isaac-sim/data
```
> 创建 Omniverse 数据目录。

```bash
mkdir -p ~/docker/isaac-sim/documents
```
> 创建文档目录。

> **为什么要创建这些目录？**
> Docker 容器每次关闭后内部数据会丢失。通过 "挂载" (volume mount) 把容器内的目录映射到主机上，
> 缓存就会保留下来。下次启动时 Isaac Sim 不需要重新编译着色器，启动速度快很多。

### 1.3 创建输出和数据集目录

```bash
mkdir -p ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main/outputs
```
> 创建模型输出目录，训练/评估的结果会保存在这里。

```bash
mkdir -p ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main/datasets
```
> 创建数据集目录，遥操作录制的数据会保存在这里。

### 1.4 配置机器人端口 (有真机时)

```bash
nano ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main/docker/env
```
> 用 nano 编辑器打开机器人配置文件 (也可以用 vim 或其他编辑器)。

文件内容如下，根据你的实际硬件修改：

```bash
export LEROBOT_CALIB=.cache/huggingface/lerobot/calibration
# 校准文件存放路径

export TELEOP_PORT=/dev/ttyACM1
# 遥操作用的领导臂 USB 端口号 (插上后用 ls /dev/ttyACM* 查看)

export ROBOT_PORT=/dev/ttyACM0
# 被控机械臂的 USB 端口号

export TELEOP_ID=orange_teleop
# 领导臂的标识名 (自己起名)

export ROBOT_ID=orange_robot
# 被控臂的标识名

export CAMERA_GRIPPER=0
# 夹爪摄像头的设备编号 (通常 /dev/video0 对应 0)

export CAMERA_EXTERNAL=4
# 外部摄像头的设备编号 (通常 /dev/video4 对应 4)
```

> **只做仿真不碰真机？** 跳过这步，用默认值即可。

---

## 第二步：构建仿真容器

### 仿真容器里有什么？

| 组件 | 作用 |
|---|---|
| Isaac Sim 4.5+ | NVIDIA 的物理仿真引擎 |
| Isaac Lab 2.3.2 | 机器人学习框架 |
| LeRobot | HuggingFace 的机器人学习库 |
| SO-101 / XLeRobot 任务 | 仿真任务定义 |

### 构建命令

```bash
cd ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main
```
> 进入 Workshop 子目录，Docker 构建需要在这个目录下执行，因为 Dockerfile 里的 COPY 指令引用了相对路径。

```bash
docker build -t teleop-docker -f docker/sim/Dockerfile.arm64 .
```
> 逐个参数解释：
> - `docker build` : 构建 Docker 镜像
> - `-t teleop-docker` : 给镜像取名叫 `teleop-docker`，后面启动时用这个名字
> - `-f docker/sim/Dockerfile.arm64` : 使用 ARM64 专用的 Dockerfile (已包含所有修复)
> - `.` : 构建上下文是当前目录 (Docker 会把当前目录的文件发送给构建进程)

> **这一步要多久？** 首次构建大约 20-40 分钟 (取决于网络速度)。构建过程中会：
> 1. 从 NVIDIA NGC 拉取 Isaac Lab 基础镜像 (~15 GB)
> 2. 克隆并安装 LeRobot
> 3. 安装所有依赖 (已用 ARM64 兼容版本)
> 4. 下载 ARM64 版本的 FFmpeg

> **如果 `Dockerfile.arm64` 不存在怎么办？** 说明你拿到的是原始仓库。运行一键构建脚本：
> ```bash
> ./build_arm64.sh
> ```
> 它会自动构建两个容器 (仿真 + 真机)。

---

## 第三步：构建真机容器

> **只做仿真？** 跳过这一步。

真机容器包含 GR00T N1.6 策略推理服务器和 SO-101 硬件控制代码。

```bash
cd ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main
```
> 确保在 Workshop 目录下。

```bash
docker build -t real-robot -f docker/real/Dockerfile.blackwell.arm64 .
```
> - `-t real-robot` : 镜像取名 `real-robot`
> - `-f docker/real/Dockerfile.blackwell.arm64` : 使用 ARM64 Blackwell 专用的 Dockerfile
>
> 这个镜像基于 `nvidia/cuda:13.0.0-devel-ubuntu24.04`，里面会：
> 1. 安装 Python 3.10 (GR00T 不支持更高版本)
> 2. 克隆并安装 Isaac-GR00T
> 3. 安装 ARM64 专用的 torchcodec wheel (从 GR00T 仓库内置的文件安装)
> 4. 编译安装 flash-attn (限制 MAX_JOBS=2 避免内存不足)
> 5. 安装 PyTorch nightly (CUDA 13.0 版)

> **这一步要多久？** 大约 30-60 分钟，flash-attn 编译是最耗时的部分。

---

## 第四步：启动仿真环境

### 方式一：使用便捷脚本 (推荐)

```bash
cd ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main
```
> 进入 Workshop 目录。

```bash
./run_teleop_arm64.sh
```
> 一键启动仿真容器，所有 ARM64 修复参数已自动配置。

### 方式二：手动运行 Docker 命令

如果你想理解每个参数，用下面的完整命令：

```bash
xhost +
```
> 允许 Docker 容器访问你的显示器 (X11 图形界面)。
> 不运行这一步的话，Isaac Sim 的 GUI 窗口打不开。

```bash
docker run --name teleop -it --privileged --gpus all \
```
> - `docker run` : 启动一个新容器
> - `--name teleop` : 给运行中的容器取名叫 `teleop` (方便管理)
> - `-it` : 交互式终端模式 (可以在容器内打字)
> - `--privileged` : 给容器完整的硬件访问权限 (USB 设备、GPU 等)
> - `--gpus all` : 允许容器使用所有 GPU

```bash
  -e "ACCEPT_EULA=Y" \
```
> 自动接受 NVIDIA 的最终用户许可协议。

```bash
  -e "PRIVACY_CONSENT=Y" \
```
> 自动接受 NVIDIA 的隐私政策。

```bash
  -e DISPLAY \
```
> 把主机的 DISPLAY 环境变量传给容器，让 GUI 窗口能显示在你的屏幕上。

```bash
  -e LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1 \
```
> 预加载 libgomp (OpenMP 运行时库)，确保它在其他库之前分配到线程本地存储空间。

```bash
  -e GLIBC_TUNABLES=glibc.rtld.optional_static_tls=2048 \
```
> 扩大静态 TLS 可用空间，确保 Isaac Sim 的大量共享库都能正常加载。

```bash
  --rm --network=host \
```
> - `--rm` : 容器退出后自动删除 (不留残余)
> - `--network=host` : 容器直接使用主机网络 (方便策略推理通信)

```bash
  -v /dev:/dev \
```
> 把主机的 `/dev` 目录挂载进容器，让容器能访问 USB 设备 (机械臂、摄像头)。

```bash
  -v /run/udev:/run/udev:ro \
```
> 挂载 udev 设备信息 (只读)，让容器能正确识别 USB 设备。

```bash
  -v "$HOME/.Xauthority:/root/.Xauthority" \
```
> 把 X11 认证文件传给容器，配合 `xhost +` 让 GUI 正常工作。

```bash
  -v "$HOME/docker/isaac-sim/cache/kit:/isaac-sim/kit/cache:rw" \
```
> 挂载 Kit 引擎缓存。`:rw` 表示可读可写。
> 这样编译好的着色器等缓存会保存在主机上，下次启动不用重新编译。

```bash
  -v "$HOME/docker/isaac-sim/cache/ov:/root/.cache/ov:rw" \
```
> 挂载 Omniverse 缓存。

```bash
  -v "$HOME/docker/isaac-sim/cache/pip:/root/.cache/pip:rw" \
```
> 挂载 pip 下载缓存，避免重复下载 Python 包。

```bash
  -v "$HOME/docker/isaac-sim/cache/glcache:/root/.cache/nvidia/GLCache:rw" \
```
> 挂载 OpenGL 着色器缓存。

```bash
  -v "$HOME/docker/isaac-sim/cache/computecache:/root/.nv/ComputeCache:rw" \
```
> 挂载 CUDA Compute 缓存。

```bash
  -v "$HOME/docker/isaac-sim/logs:/root/.nvidia-omniverse/logs:rw" \
```
> 挂载日志目录，方便在主机上查看日志排查问题。

```bash
  -v "$HOME/docker/isaac-sim/data:/root/.local/share/ov/data:rw" \
```
> 挂载 Omniverse 数据目录。

```bash
  -v "$HOME/docker/isaac-sim/documents:/root/Documents:rw" \
```
> 挂载文档目录。

```bash
  -v "$HOME/.cache/huggingface/lerobot/calibration:/root/.cache/huggingface/lerobot/calibration" \
```
> 挂载机器人校准数据目录。校准数据在主机和容器间共享。

```bash
  -v "$(pwd)/docker/env:/root/env" \
```
> 挂载机器人端口配置文件。`$(pwd)` 会自动展开为当前目录的绝对路径。

```bash
  -v "$(pwd)/source:/workspace/Sim-to-Real-SO-101-Workshop/source" \
```
> 把源代码挂载到容器内的正确路径。
> 注意：路径必须和实际代码位置完全一致，否则容器内会是空的。

```bash
  -v "$(pwd)/outputs:/workspace/Sim-to-Real-SO-101-Workshop/outputs" \
```
> 挂载输出目录，训练结果可以在主机上访问。

```bash
  -v "$(pwd)/datasets:/workspace/Sim-to-Real-SO-101-Workshop/datasets" \
```
> 挂载数据集目录，遥操作录制的数据保存在主机上。

```bash
  -v "$PROJECT_ROOT/source/xlerobot_tasks:/workspace/xlerobot_tasks" \
```
> 挂载 XLeRobot 扩展源代码到容器内。
> 容器启动时 entrypoint.sh 会自动检测到这个目录并执行 `pip install -e`。
> `$PROJECT_ROOT` 指向仓库根目录 (Sim-to-Real-SO-101-Workshop-main 的上一级)。

```bash
  -v "$PROJECT_ROOT/assets:/workspace/xlerobot_assets" \
```
> 挂载 XLeRobot 的 3D 模型资产 (机器人 USD、场景 USD) 到容器内。

```bash
  -e XLEROBOT_ASSETS_ROOT=/workspace/xlerobot_assets \
```
> 告诉 xlerobot_tasks 去哪里找 3D 模型文件。
> 不设这个环境变量的话，代码会用相对路径去找，在容器内路径不对会报错。

```bash
  teleop-docker:latest
```
> 使用名为 `teleop-docker` 的镜像 (第二步构建的) 的最新版本。

> **容器启动后自动做了什么？**
> `entrypoint.sh` 会自动执行：
> 1. `pip install -e /workspace/Sim-to-Real-SO-101-Workshop/source/sim_to_real_so101/` — 安装 SO-101 任务包
> 2. `pip install -e /workspace/xlerobot_tasks/` — 安装 XLeRobot 扩展包 (如果挂载了的话)
> 你不需要手动执行任何安装命令。

---

## 第五步：验证环境

进入容器后 (你会看到命令提示符变了)，运行以下检查：

### 5.1 检查 CUDA 是否可用

```bash
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}, Device: {torch.cuda.get_device_name(0)}')"
```
> 测试 PyTorch 能否看到 GPU。
>
> **正确输出:** `CUDA: True, Device: NVIDIA ...` (显示你的 GPU 名称)
>
> **如果输出 `CUDA: False`:** 说明 pip 偷偷替换了 CUDA 版 PyTorch，需要用 ARM64 修复版 Dockerfile 重新构建。

### 5.2 查看已注册的仿真环境

```bash
list_envs
```
> 列出所有可用的仿真任务。你应该看到类似这样的表格：
>
> | Environment | Description |
> |---|---|
> | Lerobot-So101-Teleop-Base | ... |
> | Lerobot-So101-Teleop-Vials-To-Rack | ... |
> | ... | ... |

### 5.3 用零动作测试环境能否正常启动

```bash
zero_agent --task Lerobot-So101-Teleop-Vials-To-Rack --num_envs 1 --enable_cameras
```
> 逐个参数解释：
> - `zero_agent` : 运行一个什么都不做的测试 Agent (所有关节动作为 0)
> - `--task Lerobot-So101-Teleop-Vials-To-Rack` : 加载 "抓试管放架子" 任务
> - `--num_envs 1` : 只创建 1 个仿真环境 (并行数)
> - `--enable_cameras` : 启用虚拟摄像头渲染
>
> 你应该看到 Isaac Sim 窗口弹出来，里面有一个 SO-101 机械臂、桌上有试管和架子。
> 按 `Ctrl+C` 退出。

### 5.4 用随机动作测试

```bash
random_agent --task Lerobot-So101-Teleop-Vials-To-Rack --num_envs 1 --enable_cameras
```
> 和上面一样，但机械臂会随机乱动。用来验证物理仿真和动作执行都正常。

---

## 第六步：遥操作采集数据

> 这一步的目标是：用键盘操控仿真中的机械臂完成任务 (抓试管放架子)，同时录制操作数据用于训练。

### 6.1 SO-101 单臂遥操作 (主任务)

```bash
lerobot_agent \
  --task Lerobot-So101-Teleop-Vials-To-Rack-DR \
  --num_envs 1 \
  --enable_cameras \
  --repo_id <你的HF用户名>/so101-vials-sim-dr
```
> 逐个参数解释：
> - `lerobot_agent` : 启动遥操作 + 数据录制脚本
> - `--task Lerobot-So101-Teleop-Vials-To-Rack-DR` : 带 "域随机化" 的试管任务
>   - DR = Domain Randomization (域随机化)
>   - 每次重置后会随机改变灯光、材质颜色、摄像头角度等
>   - 这样训练出来的模型在真实环境中泛化能力更强
> - `--num_envs 1` : 1 个仿真环境
> - `--enable_cameras` : 启用摄像头 (训练需要图像数据)
> - `--repo_id <你的HF用户名>/so101-vials-sim-dr` : 数据集名称
>   - 替换 `<你的HF用户名>` 为你在 huggingface.co 上的用户名
>   - 数据集后面会上传到 HuggingFace Hub

> **操作方法：**
> 1. 按 **B** 键开始录制
> 2. 用键盘控制机械臂抓住试管、放进架子 (按键说明见下方 [键盘操控说明](#键盘操控说明))
> 3. 完成后按 **N** 标记成功并重置
> 4. 如果失败了按 **R** 重置重来
> 5. 重复操作，采集 50-100 个成功的 episode (越多越好)
> 6. 按 `Ctrl+C` 结束

### 6.2 不带域随机化的版本 (调试用)

```bash
lerobot_agent \
  --task Lerobot-So101-Teleop-Vials-To-Rack \
  --num_envs 1 \
  --enable_cameras \
  --repo_id <你的HF用户名>/so101-vials-sim
```
> 和上面一样，但没有域随机化。场景固定不变，适合刚开始练习操作时使用。

### 6.3 XLeRobot 双臂遥操作 (扩展)

```bash
python scripts/teleop_xlerobot.py --enable_cameras --num_envs 1 --task XLeRobot-v0
```
> 启动 XLeRobot 双臂移动操作台的键盘遥操作。
> - `XLeRobot-v0` : 默认场景 (空地面)
> - 更多任务见 [可用的仿真环境列表](#可用的仿真环境列表)

```bash
python scripts/teleop_xlerobot.py --enable_cameras --num_envs 1 --task XLeRobot-LiftCube-v0
```
> 双臂抬起方块任务。

```bash
python scripts/teleop_xlerobot.py --enable_cameras --num_envs 1 --task XLeRobot-v0 --teleop_device xlerobot-gamepad
```
> 使用 Xbox 手柄代替键盘操控 (需要连接手柄)。

---

## 第七步：上传数据集

```bash
lerobot_push_dataset --repo_id <你的HF用户名>/so101-vials-sim-dr
```
> 把第六步录制的数据集上传到 HuggingFace Hub。
> 训练时可以从 Hub 上直接下载使用。
>
> **前提：** 需要先登录 HuggingFace CLI：
> ```bash
> pip install huggingface-hub[cli]
> huggingface-cli login
> ```
> 然后输入你的 HuggingFace API Token (在 https://huggingface.co/settings/tokens 创建)。

---

## 第八步：训练策略模型 (GR00T N1.6)

> 这一步在 DGX Spark 主机上操作 (不在 Docker 容器里)，需要 conda 环境。

### 8.1 创建 Python 3.10 环境

```bash
conda create -n gr00t python=3.10 -y
```
> 创建一个名为 `gr00t` 的 conda 虚拟环境，指定 Python 3.10。
> **为什么要 3.10？** DGX Spark 自带 Python 3.13，但 GR00T 只兼容 3.10。

```bash
conda activate gr00t
```
> 激活这个环境。后续所有命令都在这个环境里执行。

### 8.2 安装 GR00T

```bash
git clone https://github.com/NVIDIA/Isaac-GR00T.git ~/Isaac-GR00T
```
> 把 GR00T 代码克隆到主目录下。

```bash
cd ~/Isaac-GR00T
```
> 进入 GR00T 目录。

```bash
pip install scripts/deployment/dgpu/wheels/torchcodec-0.10.0a0-cp310-cp310-linux_aarch64.whl
```
> 安装 ARM64 专用的 torchcodec wheel 文件。
> 这个文件在 GR00T 仓库的 `scripts/deployment/dgpu/wheels/` 目录里。

```bash
pip install -e .
```
> 以可编辑模式安装 GR00T。`-e` 表示代码修改后不用重新安装。

### 8.3 开始训练

```bash
python scripts/train.py \
  --dataset_repo_id <你的HF用户名>/so101-vials-sim-dr \
  --num_epochs 50 \
  --batch_size 32 \
  --output_dir ~/sim2real/models/groot-so101-vials
```
> 逐个参数解释：
> - `scripts/train.py` : GR00T 的训练脚本
> - `--dataset_repo_id` : 第七步上传的数据集 ID
> - `--num_epochs 50` : 训练 50 个 epoch (根据数据量和效果调整)
> - `--batch_size 32` : 每批处理 32 个样本 (GB10 有 92GB 显存，可以开大一些)
> - `--output_dir` : 训练好的模型保存位置

> **训练多久？** 取决于数据集大小和 epoch 数，通常 1-4 小时。
> 训练完成后，模型会保存在 `~/sim2real/models/groot-so101-vials/` 目录。

---

## 第九步：部署到真实 SO-101 机械臂

> **前提：** 你需要有真实的 SO-101 机械臂硬件，并通过 USB 连接到 DGX Spark。

### 9.1 启动真机容器

#### 方式一：便捷脚本

```bash
cd ~/xlerobot-sim2real/Sim-to-Real-SO-101-Workshop-main
./run_real_robot_arm64.sh
```

#### 方式二：手动命令

```bash
xhost +
```
> 允许容器访问显示器。

```bash
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
> 参数说明与仿真容器类似，关键区别：
> - `-v "$HOME/sim2real/models:/workspace/models"` : 把训练好的模型挂载进容器
> - `-v "$(pwd)/docker/real/scripts:..."` : 把真机控制脚本挂载进容器

### 9.2 校准机械臂 (首次使用必须做)

```bash
cd /workspace/Isaac-GR00T/gr00t/eval/real_robot/SO100
```
> 进入真机控制脚本目录。

```bash
python so101_control.py --port /dev/ttyACM0 --id my_robot --calibrate
```
> 启动校准程序。
> - `--port /dev/ttyACM0` : 机械臂的 USB 端口 (参考 `docker/env` 文件里的 ROBOT_PORT)
> - `--id my_robot` : 给这个机械臂起个名字 (用于保存校准数据)
> - `--calibrate` : 进入校准模式
>
> 按照屏幕提示，把机械臂的每个关节转到指定位置。

### 9.3 检查校准质量

```bash
python so101_check_calibration.py --id my_robot
```
> 对比你的校准结果和统计基准值。
> 如果某个关节偏差超过 2 个标准差，建议重新校准。

### 9.4 测试手动控制

```bash
python so101_manual_control.py --port /dev/ttyACM0 --id my_robot
```
> 用键盘手动控制每个关节，验证机械臂响应正常。
> - 上/下箭头：选择关节
> - 左/右箭头：调整关节角度
> - Z：所有关节归零
> - Q 或 ESC：退出

### 9.5 启动策略推理服务

> 需要两个终端。在容器内打开第二个终端：
> ```bash
> docker exec -it real-robot /bin/bash
> ```

**终端 1：启动 GR00T 策略服务器**

```bash
cd /Isaac-GR00T
python scripts/serve.py --model_path /workspace/models/groot-so101-vials
```
> 加载训练好的模型，启动 ZeroMQ 推理服务。
> 服务会监听在 `tcp://localhost:5555`。

**终端 2：运行真机评估**

```bash
cd /workspace/Isaac-GR00T/gr00t/eval/real_robot/SO100
python so101_eval.py \
  --robot_port /dev/ttyACM0 \
  --robot_id my_robot \
  --server_url tcp://localhost:5555 \
  --task "pick up the vial and place it in the yellow rack"
```
> 逐个参数解释：
> - `--robot_port` : 机械臂 USB 端口
> - `--robot_id` : 校准时用的名字
> - `--server_url` : 终端 1 启动的策略服务地址
> - `--task` : 语言指令 (GR00T 是视觉语言动作模型，需要文字描述任务)
>
> 机械臂会自动开始执行策略，尝试抓试管放架子。

---

## 可用的仿真环境列表

### SO-101 单臂任务

| 环境名 | 用途 | 说明 |
|---|---|---|
| `Lerobot-So101-Teleop-Base` | 调试 | 基础遥操作，无任务物体 |
| `Lerobot-So101-Teleop-Task` | 调试 | 灯箱 + 摄像头测试 |
| `Lerobot-So101-Teleop-Vials-To-Rack` | **主任务** | 抓试管放架子 (固定外观) |
| `Lerobot-So101-Teleop-Vials-To-Rack-DR` | **主任务** | 抓试管放架子 (带域随机化，推荐) |
| `Lerobot-So101-Teleop-Vials-To-Rack-Eval` | 评估 | 固定外观，用于策略评估 |
| `Lerobot-So101-Teleop-Vials-To-Rack-DR-Eval` | 评估 | 带域随机化，用于策略评估 |

### XLeRobot 双臂任务

| 环境名 | 说明 |
|---|---|
| `XLeRobot-v0` | 默认空场景 (双臂 17 自由度) |
| `XLeRobot-LiftCube-v0` | 抬起方块任务 |
| `XLeRobot-Loft-v0` | 阁楼场景环境 |

---

## 键盘操控说明

### SO-101 单臂 (lerobot_agent 中)

| 按键 | 作用 |
|---|---|
| **B** | 开始录制 |
| **R** | 标记失败、重置场景 |
| **N** | 标记成功、重置场景 |
| W / S | 前进 / 后退 |
| A / D | 左移 / 右移 |
| Q / E | 上升 / 下降 |
| U / O | 夹爪张开 / 关闭 |
| Ctrl+C | 退出程序 |

### XLeRobot 双臂 (teleop_xlerobot.py 中)

#### 右臂

| 按键 | 作用 |
|---|---|
| W / S | 前进 / 后退 |
| A / D | 左移 / 右移 |
| Q / E | 上升 / 下降 |
| J / L | 偏航 (左转 / 右转) |
| K / I | 俯仰 (抬头 / 低头) |
| U / O | 夹爪张开 / 关闭 |

#### 左臂

> 按住 **Shift** 再按右臂的按键就是控制左臂。

#### 头部

| 按键 | 作用 |
|---|---|
| 7 / 9 | 头部左转 / 右转 |
| 8 / 0 | 头部抬起 / 低下 |

#### 移动底盘

| 按键 | 作用 |
|---|---|
| 方向键上/下 | 前进 / 后退 |
| 方向键左/右 | 左平移 / 右平移 |
| Z / X | 左旋转 / 右旋转 |
| 1 / 2 / 3 | 速度档位 (慢 / 中 / 快) |

#### 通用控制

| 按键 | 作用 |
|---|---|
| B | 开始控制 |
| R | 重置场景 |
| N | 标记成功 |
| Ctrl+C | 退出 |

---

## 手柄操控说明

> 需要 Xbox 手柄或兼容手柄，通过 USB 或蓝牙连接到 DGX Spark。

| 输入 | 作用 |
|---|---|
| 左摇杆 | 手臂 前后/左右 移动 |
| 右摇杆 | 手臂 上下 + 偏航旋转 |
| 十字键 上/下 | 手臂 俯仰 |
| RT / RB | 夹爪 张开/关闭 |
| LB (按住) | 切换到左臂 |
| 十字键 左/右 | 头部 左右转 |
| LT (模拟量) | 头部 俯仰 |

---

## 常见报错与解决

| 报错信息 | 原因 | 解决方法 |
|---|---|---|
| `cannot allocate memory in static TLS block` | ARM64 TLS 空间不足 | 加 `LD_PRELOAD` 和 `GLIBC_TUNABLES` 环境变量 |
| `torch.cuda.is_available()` 返回 `False` | CUDA PyTorch 被 CPU 版替换 | 重新构建容器，使用动态版本捕获 |
| `No matching distribution found for torchcodec` | ARM64 包版本不同 | 改用 `>=0.11.0,<0.12.0` |
| 容器内 `/workspace/...` 是空的 | `-v` 挂载路径写错了 | 检查路径是否和实际克隆位置一致，用 `$(pwd)` |
| `ModuleNotFoundError: No module named 'flash_attn'` | flash-attn 需要源码编译 | `MAX_JOBS=2 pip install flash-attn --no-build-isolation` |
| GR00T 安装失败 | Python 版本太高 | 用 conda 创建 Python 3.10 环境 |
| `Exec format error` | 下载了 x86_64 的二进制文件 | 确认使用 ARM64 版 Dockerfile |
| `Permission denied` 访问 `/dev/ttyACM0` | USB 端口权限不够 | `docker run` 加了 `--privileged` 就行；主机上可以 `sudo chmod 666 /dev/ttyACM0` |
| Isaac Sim 启动很慢 (>5 分钟) | 首次需要编译着色器 | 正常现象，缓存挂载后第二次会快很多 |
| 没有 GUI 窗口弹出 | X11 转发没配置 | 确认运行了 `xhost +` 并传入了 `-e DISPLAY` |
| `ImportError: xlerobot_tasks.assets.xlerobot` | 原仓库缺少 assets 模块 | 本仓库已修复；确认用的是修复版代码 |
| `ModuleNotFoundError: sim_to_real_so101` | 缺少 `__init__.py` | 本仓库已修复；确认 `source/sim_to_real_so101/__init__.py` 存在 |
| `import xlerobot_tasks` 失败 | 容器内没挂载 xlerobot_tasks | 使用 `./run_teleop_arm64.sh` 启动 (自动挂载) |
| XLeRobot 环境找不到 USD 模型 | `XLEROBOT_ASSETS_ROOT` 没设 | 使用 `./run_teleop_arm64.sh` 启动 (自动设置) |

---

## 项目目录结构

```
xlerobot-sim2real/
│
├── README.md                           # 英文说明
├── GUIDE_CN.md                         # 本文件 (中文指南)
├── isaac sim lerobot.gif               # 演示动图
│
├── assets/                             # XLeRobot 机器人 3D 模型 (USD 格式)
│   ├── robots/xlerobot/                #   机器人 USD 模型
│   │   └── xlerobot.usd               #   (被 xlerobot_tasks.assets.xlerobot 引用)
│   └── scenes/                         #   场景资产
│       ├── table_with_cube/scene.usd   #   (被 xlerobot_tasks.assets.scenes 引用)
│       └── lightwheel_loft/LW_Loft.usd
│
├── scripts/                            # XLeRobot 遥操作脚本
│   ├── teleop_xlerobot.py              #   键盘/手柄遥操作
│   ├── test_xlerobot_env.py            #   环境测试 (随机动作)
│   └── test_xlerobot_env_debug.py      #   调试脚本 (详细输出)
│
├── source/xlerobot_tasks/              # XLeRobot IsaacLab 扩展 (pip install -e .)
│   ├── setup.py                        #   find_packages() 自动发现所有子包
│   ├── pyproject.toml                  #   构建系统配置
│   └── xlerobot_tasks/                 #   Python 包根目录
│       ├── __init__.py                 #   from .tasks import * (触发环境注册)
│       ├── assets/                     #   [新增] 机器人和场景的 Python 配置
│       │   ├── __init__.py             #   [新增]
│       │   ├── xlerobot.py             #   [新增] XLEROBOT_CFG (ArticulationCfg)
│       │   └── scenes.py              #   [新增] TABLE_WITH_CUBE_CFG, LOFT_CFG
│       ├── devices/                    #   输入设备驱动
│       │   ├── device_base.py          #     基类 (键盘监听、坐标转换)
│       │   ├── xlerobot_keyboard.py    #     键盘控制器 (WASD + IK)
│       │   ├── xlerobot_gamepad.py     #     手柄控制器 (Xbox)
│       │   └── gamepad_utils.py        #     Pygame 手柄工具
│       ├── tasks/xlerobot/             #   环境配置 + MDP 定义
│       │   ├── __init__.py             #     注册 3 个 Gym 环境
│       │   ├── xlerobot_env_cfg.py     #     基础环境配置
│       │   ├── xlerobot_lift_cube_env_cfg.py  # 抬方块任务
│       │   ├── xlerobot_loft_env_cfg.py       # 阁楼场景
│       │   └── mdp/                    #     观测、终止函数
│       └── utils/                      #   工具函数
│           ├── constant.py             #     关节名、ASSETS_ROOT 路径
│           ├── math_utils.py           #     旋转向量转欧拉角
│           ├── domain_randomization.py #     域随机化辅助
│           └── general_assets.py       #     USD 解析工具
│
├── docs/
│   └── DEVELOPMENT.md                  #   开发文档 & 架构说明
│
└── Sim-to-Real-SO-101-Workshop-main/   # SO-101 Workshop (NVIDIA 官方)
    │
    ├── build_arm64.sh                  # 一键构建两个 ARM64 容器
    ├── run_teleop_arm64.sh             # 一键启动仿真容器 (含 xlerobot 挂载)
    ├── run_real_robot_arm64.sh         # 一键启动真机容器
    │
    ├── docker/
    │   ├── sim/
    │   │   ├── Dockerfile              #   原始仿真 Dockerfile (x86_64)
    │   │   ├── Dockerfile.arm64        #   ARM64 修复版仿真 Dockerfile
    │   │   └── entrypoint.sh           #   容器启动脚本 (自动安装两个包)
    │   ├── real/
    │   │   ├── Dockerfile.blackwell    #   原始 Blackwell Dockerfile
    │   │   ├── Dockerfile.blackwell.arm64  # ARM64 修复版
    │   │   ├── Dockerfile.ada          #   Ada GPU 版 (非 DGX Spark)
    │   │   ├── build.sh                #   构建脚本
    │   │   └── scripts/                #   真机控制脚本
    │   │       ├── so101_control.py    #     机械臂控制 + 校准
    │   │       ├── so101_eval.py       #     策略评估
    │   │       ├── so101_manual_control.py  # 手动关节控制
    │   │       ├── so101_check_calibration.py  # 校准检查
    │   │       └── so101_calibration_stats.py  # 校准统计
    │   ├── env                         #   机器人端口配置
    │   └── utils.sh                    #   Shell 工具函数
    │
    └── source/sim_to_real_so101/       # SO-101 仿真任务代码 (pip install -e .)
        ├── __init__.py                 #   [新增] 包根目录标识 (原来缺失)
        ├── setup.py                    #   find_packages(where="..") 从父目录发现包
        ├── pyproject.toml              #   入口点 + requires-python>=3.10
        ├── scripts/                    #   主要脚本 (注册为命令行工具)
        │   ├── __init__.py             #   [新增] 让 entry_points 能找到脚本
        │   ├── lerobot_agent.py        #     遥操作 + 录制
        │   ├── lerobot_eval.py         #     策略评估
        │   ├── lerobot_push_dataset.py #     上传数据集
        │   ├── list_envs.py            #     列出环境
        │   ├── random_agent.py         #     随机动作测试
        │   └── zero_agent.py           #     零动作测试
        ├── tasks/                      #   仿真环境定义
        │   ├── __init__.py             #     注册 6 个 Gym 环境
        │   ├── so101_env_cfg.py        #     SO-101 基础配置
        │   ├── task_env_cfg.py         #     任务 + 域随机化配置
        │   └── vials_to_rack_env_cfg.py #    试管任务配置
        ├── mdp/                        #   MDP 组件
        │   ├── __init__.py             #     统一导出 obs + terms + resets
        │   ├── obs.py                  #     观测函数 (关节位、图像)
        │   ├── terms.py                #     任务项 (抓取检测、放置检测)
        │   └── resets.py               #     域随机化 (灯光、颜色、摄像头)
        ├── gr00t_client/               #   GR00T 策略推理客户端
        │   ├── server_client.py        #     ZeroMQ 推理服务
        │   ├── policy.py               #     策略基类
        │   └── types.py                #     数据类型定义
        ├── utils/                      #   工具类
        │   ├── lerobot_interface.py    #     仿真/真机桥接
        │   ├── lerobot_recorder.py     #     数据集录制器
        │   └── keyboard.py            #     键盘控制器
        └── assets/                     #   资产文件
            ├── so101.py                #     SO-101 机器人配置 (ArticulationCfg)
            ├── usd/                    #     3D 模型 (机器人、试管、架子)
            └── hdri/                   #     环境光照贴图 (24 张 EXR)
```

> **标注 `[新增]` 的文件** 是本仓库为修复 Python 包结构而新建的。没有这些文件，`pip install -e .` 后 import 会报错。

---

> **致谢：** ARM64 适配方案来源于 Kabilankb 的 DGX Spark 调试记录。
> **许可证：** Apache-2.0。详见 `Sim-to-Real-SO-101-Workshop-main/LICENSE`。
