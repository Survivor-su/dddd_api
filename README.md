# dddd_api

基于 [ddddocr](https://github.com/sml2h3/ddddocr) 的验证码识别 HTTP 服务，GPU 加速。

## 依赖

- Python 3.14+
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- NVIDIA GPU（Pascal 及更新架构，如 GTX 10xx / MX250 / RTX 系列）

## 快速开始

```bash
# 首次运行会自动创建虚拟环境并按 uv.lock 安装依赖
./run.sh
```

服务默认监听 `0.0.0.0:8000`。

后台启动：

```bash
./run.sh -d
```

自定义端口与监听地址：

```bash
PORT=9000 HOST=127.0.0.1 ./run.sh
```

## 接口

### POST /ocr

上传图片，返回识别结果。

```bash
curl -X POST http://127.0.0.1:8000/ocr -F "file=@captcha.gif"
```

```json
{"result": "f8kh", "model": "GPU"}
```

`model` 字段标识本次请求实际使用的推理引擎（GPU 或 CPU）。

错误响应：

| 状态码 | 说明 |
|---|---|
| 400 | 非图片类型或文件为空 |
| 422 | 缺少 `file` 字段 |

## 压测

```bash
.venv/bin/python test.py
```

`test.py` 中的 `URL` 需指向实际服务地址，并发数由 `CONCURRENT` 控制。

## GPU 说明

本项目同时加载 GPU 与 CPU 两个推理实例，请求在两者间轮询分发。

### CUDA 版本约束

| 组件 | 锁定版本 | 原因 |
|---|---|---|
| onnxruntime-gpu | 1.26.0 | 1.27+ 为 CUDA 13 构建，Pascal 架构（sm_61）不再受支持 |
| nvidia-cudnn-cu12 | 9.8.0.87 | 9.9+ 与 onnxruntime-gpu 1.26 不兼容，报 `CUDNN_STATUS_EXECUTION_FAILED_CUDART` |

相关配置位于 `pyproject.toml`：

```toml
[tool.uv]
# onnxruntime(CPU) 与 onnxruntime-gpu 写入同一个 onnxruntime/ 模块目录，
# 必须排除 CPU 版，否则会覆盖 GPU 的 .so 导致 GPU 静默失效
exclude-dependencies = ["onnxruntime"]
override-dependencies = ["nvidia-cudnn-cu12==9.8.0.87"]
```

### 常见问题

**GPU 未生效，响应中 `model` 始终为 `CPU`**

onnxruntime 需要显式的库搜索路径才能加载 pip 安装的 CUDA 库，`run.sh` 已通过 `LD_LIBRARY_PATH` 处理。若手动执行其他启动方式，需自行设置该变量，否则会静默回退到 CPU 且不报错。

**显存不足**

`run.sh` 使用默认的 GPU 内存上限。MX250 等 2GB 显存设备建议降低并发，`main.py` 中的 `MAX_OCR_CONCURRENT` 控制同时进行的 OCR 请求数。

## 目录结构

```
.
├── main.py          # FastAPI 服务与 GPU/CPU 推理实例
├── run.sh           # 启动脚本
├── test.py          # 并发压测脚本
├── pyproject.toml   # 依赖声明与 uv 配置
├── uv.lock          # 锁定的依赖版本
└── captcha.gif      # 测试用图片
```
