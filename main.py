import asyncio
import itertools
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import ddddocr
import uvicorn

app = FastAPI()

# 同时进行的 OCR 请求数上限
MAX_OCR_CONCURRENT = 10
ocr_semaphore = asyncio.Semaphore(MAX_OCR_CONCURRENT)

# ---- 加载两个 OCR 实例：GPU + CPU ----
print("[启动] 正在加载 OCR 模型（GPU）...")
ocr_gpu = ddddocr.DdddOcr(beta=True, use_gpu=True)
print("[启动] OCR 模型（GPU）加载完成")

print("[启动] 正在加载 OCR 模型（CPU）...")
ocr_cpu = ddddocr.DdddOcr(beta=True, use_gpu=False)
print("[启动] OCR 模型（CPU）加载完成")

# 轮询分发：GPU → CPU → GPU → CPU ...
ocr_instances = itertools.cycle([("GPU", ocr_gpu), ("CPU", ocr_cpu)])


@app.post("/ocr")
async def recognize_captcha(file: UploadFile = File(...)):
    """接收图片文件，返回 OCR 识别结果"""
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="仅支持图片文件")

    contents = await file.read()

    if not contents:
        raise HTTPException(status_code=400, detail="文件为空")

    # 轮询选取一个 OCR 实例
    label, ocr = next(ocr_instances)

    # 推入线程执行，避免阻塞事件循环
    async with ocr_semaphore:
        result = await asyncio.to_thread(ocr.classification, contents)

    return JSONResponse(content={"result": result, "model": label})


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
