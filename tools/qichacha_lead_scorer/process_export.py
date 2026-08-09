#!/usr/bin/env python3
"""
本地企业导出处理脚本（完善版流程，不含爬虫）。

你原来的脚本里用 Cookie 请求第三方站点私有接口的部分，这里不会实现。
请先用平台官方导出 / 已合法获得的 JSON、CSV、Excel，再跑本脚本：

1. 归一化字段（兼容 company_real_name / 经营范围 等）
2. 按 company_name_digest 或公司名去重
3. 按跨境专线规则打分、分池
4. 可选：城市过滤、只要有电话、按分数过滤
5. 导出 Excel

示例：
  python3 process_export.py -i sample_api_export.json -o 跨境电商客户测试.xlsx
  python3 process_export.py -i sample_api_export.json -o hot.xlsx \\
      --cities 深圳,广州 --min-score 3 \\
      --actions priority_call,maybe_call,peer_pool --require-phone
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from qichacha_lead_scorer.cli import main


if __name__ == "__main__":
    raise SystemExit(main())
