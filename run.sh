#!/bin/bash
# dddd_api 启动脚本（本地 GPU 版）
# 用法: ./run.sh
set -e

cd "$(dirname "$0")"
SP=$(.venv/bin/python -c "import site;print(site.getsitepackages()[0])")

export LD_LIBRARY_PATH="$SP/nvidia/cublas/lib:$SP/nvidia/cudnn/lib:$SP/nvidia/cuda_runtime/lib:$SP/nvidia/cufft/lib:$SP/nvidia/curand/lib:$SP/nvidia/cuda_nvrtc/lib:$SP/nvidia/nvjitlink/lib:${LD_LIBRARY_PATH:-}"

exec .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --timeout-graceful-shutdown 120
