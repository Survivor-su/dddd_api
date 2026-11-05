# ============================================================
# dddd_api - 验证码识别 OCR 服务 Docker 镜像（GPU 版）
# ============================================================

# ---------- 阶段1: 构建依赖 ----------
FROM nvidia/cuda:12.6.0-cudnn-runtime-ubuntu22.04 AS builder

# 跳过 tzdata 等包的交互式提示
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# 安装 deadsnakes PPA 获取 Python 3.14 + 系统运行库
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.14 \
        python3.14-venv \
        python3.14-dev \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv 包管理器
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# 先复制依赖文件，利用 Docker 缓存层
COPY pyproject.toml uv.lock ./

# 创建虚拟环境 -> 安装依赖
# GPU 版 onnxruntime 及其 CUDA/cuDNN 运行库已由 uv.lock 锁定
# (onnxruntime-gpu==1.26.0 + nvidia-*-cu12)，无需再单独 pip install
ENV UV_PYTHON=python3.14
RUN uv venv && \
    uv sync --frozen --no-dev

# ---------- 阶段2: 运行镜像 ----------
FROM nvidia/cuda:12.6.0-cudnn-runtime-ubuntu22.04

# 跳过 tzdata 等包的交互式提示
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# 安装运行时依赖（Python 3.14 + 系统库）
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.14 \
        python3.14-venv \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 从构建阶段复制虚拟环境（已包含 onnxruntime-gpu 及 nvidia-*-cu12 运行库）
COPY --from=builder /app/.venv /app/.venv

# onnxruntime 不会自动加载 pip 安装的 CUDA 库，必须显式指定库搜索路径，
# 否则 CUDAExecutionProvider 加载失败并静默回退到 CPU
ENV LD_LIBRARY_PATH=/app/.venv/lib/python3.14/site-packages/nvidia/cublas/lib:/app/.venv/lib/python3.14/site-packages/nvidia/cudnn/lib:/app/.venv/lib/python3.14/site-packages/nvidia/cuda_runtime/lib:/app/.venv/lib/python3.14/site-packages/nvidia/cufft/lib:/app/.venv/lib/python3.14/site-packages/nvidia/curand/lib:/app/.venv/lib/python3.14/site-packages/nvidia/cuda_nvrtc/lib:/app/.venv/lib/python3.14/site-packages/nvidia/nvjitlink/lib

# 复制应用代码
COPY main.py ./

# 暴露服务端口
EXPOSE 8000

# 启动服务（ddddocr 初始化较慢，放宽 graceful_timeout）
CMD ["/app/.venv/bin/uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--timeout-graceful-shutdown", "120"]
