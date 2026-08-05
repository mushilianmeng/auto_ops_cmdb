"""CLI：从 CSV 批量评分企查查经营范围。"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

from .scorer import score_business_scope


DEFAULT_NAME_FIELDS = ("company_name", "企业名称", "公司名称", "名称", "name")
DEFAULT_SCOPE_FIELDS = ("business_scope", "经营范围", "scope")


def _pick_field(row: dict[str, str], candidates: tuple[str, ...]) -> str:
    lower_map = {k.strip().lower(): v for k, v in row.items() if k}
    for key in candidates:
        if key in row and row[key] is not None:
            return str(row[key]).strip()
        if key.lower() in lower_map and lower_map[key.lower()] is not None:
            return str(lower_map[key.lower()]).strip()
    return ""


def score_csv(
    input_path: Path,
    output_path: Path,
    name_field: str | None = None,
    scope_field: str | None = None,
    min_score: int | None = None,
    actions: set[str] | None = None,
) -> int:
    with input_path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            raise SystemExit("输入 CSV 缺少表头")
        rows = list(reader)

    results = []
    for row in rows:
        if name_field:
            name = str(row.get(name_field, "") or "").strip()
        else:
            name = _pick_field(row, DEFAULT_NAME_FIELDS)

        if scope_field:
            scope = str(row.get(scope_field, "") or "").strip()
        else:
            scope = _pick_field(row, DEFAULT_SCOPE_FIELDS)

        result = score_business_scope(scope, name)
        if min_score is not None and result.score < min_score:
            continue
        if actions and result.action not in actions:
            continue

        payload = {**row, **result.to_dict()}
        results.append(payload)

    if not results:
        # 仍写出表头，方便流水线
        fieldnames = list(rows[0].keys()) if rows else ["company_name", "business_scope"]
        extra = [
            "score",
            "action",
            "pool",
            "matched_rules",
            "matched_keywords",
            "tags",
            "reasons",
        ]
        for key in extra:
            if key not in fieldnames:
                fieldnames.append(key)
        with output_path.open("w", encoding="utf-8-sig", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
        return 0

    # 按分数降序，便于先打高意向
    results.sort(key=lambda r: int(r.get("score") or 0), reverse=True)

    fieldnames: list[str] = []
    seen: set[str] = set()
    for row in results:
        for key in row.keys():
            if key not in seen:
                fieldnames.append(key)
                seen.add(key)

    with output_path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(results)

    return len(results)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="根据企查查经营范围，筛选跨境专线潜在客户",
    )
    parser.add_argument(
        "-i",
        "--input",
        default=None,
        help="输入 CSV（需含公司名、经营范围列）",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="输出 CSV 路径",
    )
    parser.add_argument("--name-field", default=None, help="公司名列名")
    parser.add_argument("--scope-field", default=None, help="经营范围列名")
    parser.add_argument("--min-score", type=int, default=None, help="最低分过滤")
    parser.add_argument(
        "--actions",
        default=None,
        help="只保留指定动作，逗号分隔：priority_call,maybe_call,peer_pool,skip",
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="对单条经营范围文本演示评分（配合 --scope-text）",
    )
    parser.add_argument("--scope-text", default="", help="单条经营范围（--demo 用）")
    parser.add_argument("--company", default="示例公司", help="公司名（--demo 用）")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.demo:
        result = score_business_scope(args.scope_text, args.company)
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
        return 0

    if not args.input or not args.output:
        parser.error("批量模式需要同时提供 -i/--input 与 -o/--output（或改用 --demo）")

    actions = None
    if args.actions:
        actions = {a.strip() for a in args.actions.split(",") if a.strip()}

    count = score_csv(
        input_path=Path(args.input),
        output_path=Path(args.output),
        name_field=args.name_field,
        scope_field=args.scope_field,
        min_score=args.min_score,
        actions=actions,
    )
    print(f"已写出 {count} 条到 {args.output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
