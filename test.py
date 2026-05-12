import aiohttp
import asyncio
import time

# ============================================================
# 配置
# ============================================================
URL = "http://47.109.178.162:35800/ocr"
CONCURRENT = 500   # 同时并发数
TOTAL = 500        # 总请求数

# 读取图片二进制（只读，可以安全共享）
with open("captcha.gif", "rb") as f:
    IMG_DATA = f.read()


def make_form_data():
    """每个请求创建独立的 FormData，避免并发共享导致数据错乱"""
    form = aiohttp.FormData()
    form.add_field("file", IMG_DATA, filename="captcha.gif", content_type="image/gif")
    return form


async def send_request(session, request_id, semaphore):
    """发送单次请求"""
    async with semaphore:
        try:
            start = time.perf_counter()
            async with session.post(URL, data=make_form_data()) as resp:
                elapsed = time.perf_counter() - start
                if resp.status == 200:
                    result = await resp.json()
                    return (request_id, True, result, elapsed)
                else:
                    text = await resp.text()
                    return (request_id, False, f"HTTP {resp.status}: {text}", elapsed)
        except Exception as e:
            elapsed = time.perf_counter() - time.perf_counter()  # 获取异常时间点
            return (request_id, False, str(e), 0.0)


async def main():
    print(f"异步并发测试: 总={TOTAL}, 并发={CONCURRENT}")
    print("=" * 55)

    semaphore = asyncio.Semaphore(CONCURRENT)

    # 配置连接池：limit 必须 >= 并发数，否则请求会排队
    connector = aiohttp.TCPConnector(limit=CONCURRENT + 10, force_close=True)
    timeout = aiohttp.ClientTimeout(total=30)

    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        # 计时：墙上时钟
        wall_start = time.perf_counter()
        tasks = [send_request(session, i, semaphore) for i in range(TOTAL)]
        results = await asyncio.gather(*tasks)
        wall_elapsed = time.perf_counter() - wall_start

    # ---- 统计 ----
    success_list = [r for r in results if r[1]]
    fail_list = [r for r in results if not r[1]]
    latencies = sorted([r[3] for r in success_list])

    # 打印前 10 个结果
    for req_id, ok, detail, elapsed in results[:10]:
        status = "成功" if ok else "失败"
        print(f"[{req_id:3d}] {status} | {detail} | 耗时: {elapsed:.3f}s")

    print("\n========== 统计 ==========")
    print(f"成功: {len(success_list)}, 失败: {len(fail_list)}")
    print(f"总耗时（墙上）: {wall_elapsed:.3f}s")
    print(f"实际 QPS: {TOTAL / wall_elapsed:.2f}")

    if latencies:
        print(f"平均耗时: {sum(latencies) / len(latencies):.3f}s")
        print(f"最小耗时: {min(latencies):.3f}s")
        print(f"最大耗时: {max(latencies):.3f}s")
        p50 = latencies[int(len(latencies) * 0.50)]
        p90 = latencies[int(len(latencies) * 0.90)]
        p99 = latencies[int(len(latencies) * 0.99)]
        print(f"P50: {p50:.3f}s  P90: {p90:.3f}s  P99: {p99:.3f}s")

    # 打印失败详情
    if fail_list:
        print(f"\n失败详情:")
        for req_id, ok, detail, elapsed in fail_list[:5]:
            print(f"  [{req_id}] {detail}")


if __name__ == "__main__":
    asyncio.run(main())
