#!/bin/bash
# dddd_api 启动脚本（本地 GPU 版）
#
# 用法：
#   ./run.sh          前台启动
#   ./run.sh -d       后台启动，日志写入 server.log
#
# 环境变量：
#   PORT       监听端口，默认 8000
#   HOST       监听地址，默认 0.0.0.0
set -euo pipefail

cd "$(dirname "$0")"

PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"

# ---- 依赖检查 ----
if [ ! -x .venv/bin/python ]; then
    echo "[run.sh] 未找到虚拟环境，正在创建..."
    if ! command -v uv >/dev/null 2>&1; then
        echo "[run.sh] 需要 uv，请先安装: https://docs.astral.sh/uv/getting-started/installation/" >&2
        exit 1
    fi
    uv sync --frozen
fi

# ---- CUDA 库路径 ----
# onnxruntime 不会自动加载 pip 安装的 CUDA 库，必须显式指定，
# 否则 CUDAExecutionProvider 加载失败并静默回退到 CPU
SP=$(.venv/bin/python -c "import site;print(site.getsitepackages()[0])")
export LD_LIBRARY_PATH="$SP/nvidia/cublas/lib:$SP/nvidia/cudnn/lib:$SP/nvidia/cuda_runtime/lib:$SP/nvidia/cufft/lib:$SP/nvidia/curand/lib:$SP/nvidia/cuda_nvrtc/lib:$SP/nvidia/nvjitlink/lib:${LD_LIBRARY_PATH:-}"

# ---- 启动 ----
ARGS=(--host "$HOST" --port "$PORT" --timeout-graceful-shutdown 120)

if [ "${1:-}" = "-d" ]; then
    # setsid 让服务脱离当前进程组，避免 pkill 时被连带杀死
    setsid nohup .venv/bin/uvicorn main:app "${ARGS[@]}" > server.log 2>&1 < /dev/null &
    echo "[run.sh] 后台启动中，日志: $(pwd)/server.log"
    sleep 2
    if kill -0 $! 2>/dev/null; then
        echo "[run.sh] PID: $!"
    else
        echo "[run.sh] 启动失败，请查看 server.log" >&2
        exit 1
    fi
else
    exec .venv/bin/uvicorn main:app "${ARGS[@]}"
fi
