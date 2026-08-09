"""CLI：本地企业导出按经营范围规则打分。"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .pipeline import run_pipeline
from .scorer import score_business_scope


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "根据经营范围规则筛选跨境专线潜客。"
            "输入为本地 JSON/CSV/Excel（合法导出），不包含任何第三方站点爬取。"
        ),
    )
    parser.add_argument("-i", "--input", default=None, help="输入文件：.json / .csv / .xlsx")
    parser.add_argument("-o", "--output", default=None, help="输出文件：.xlsx 或 .csv")
    parser.add_argument("--min-score", type=int, default=None, help="最低意向分")
    parser.add_argument(
        "--actions",
        default=None,
        help="只保留指定动作：priority_call,maybe_call,peer_pool,skip",
    )
    parser.add_argument(
        "--cities",
        default=None,
        help="城市过滤，逗号分隔，如：深圳,广州",
    )
    parser.add_argument(
        "--require-phone",
        action="store_true",
        help="只保留有公开电话的记录",
    )
    parser.add_argument("--demo", action="store_true", help="单条经营范围演示")
    parser.add_argument("--scope-text", default="", help="单条经营范围（--demo）")
    parser.add_argument("--company", default="示例公司", help="公司名（--demo）")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.demo:
        result = score_business_scope(args.scope_text, args.company)
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
        return 0

    if not args.input or not args.output:
        parser.error("批量模式需要 -i/--input 与 -o/--output（或改用 --demo）")

    actions = None
    if args.actions:
        actions = {a.strip() for a in args.actions.split(",") if a.strip()}

    cities = None
    if args.cities:
        cities = {c.strip() for c in args.cities.split(",") if c.strip()}

    count = run_pipeline(
        input_path=Path(args.input),
        output_path=Path(args.output),
        min_score=args.min_score,
        actions=actions,
        cities=cities,
        require_phone=args.require_phone,
    )
    print(f"已写出 {count} 条到 {args.output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
