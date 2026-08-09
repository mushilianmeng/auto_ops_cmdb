"""本地企业导出 → 归一化 → 去重 → 规则打分 → 过滤导出。"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .io_util import load_records, save_csv, save_excel
from .normalize import dedupe_companies, normalize_company
from .scorer import score_business_scope


TARGET_CITIES = {"深圳", "广州", "深圳市", "广州市"}


def process_records(
    raw_rows: list[dict[str, Any]],
    *,
    min_score: int | None = None,
    actions: set[str] | None = None,
    cities: set[str] | None = None,
    require_phone: bool = False,
) -> list[dict[str, Any]]:
    normalized = [normalize_company(row) for row in raw_rows]
    companies = dedupe_companies(normalized)

    results: list[dict[str, Any]] = []
    for company in companies:
        scored = score_business_scope(
            company.get("business_scope", ""),
            company.get("company_name", ""),
        )
        payload = {**company, **scored.to_dict()}

        if cities:
            city = payload.get("city") or ""
            if city not in cities and not any(c in (payload.get("address") or "") for c in cities):
                continue

        if require_phone and not payload.get("phone"):
            continue

        if min_score is not None and int(payload.get("score") or 0) < min_score:
            continue

        if actions and payload.get("action") not in actions:
            continue

        results.append(payload)

    results.sort(key=lambda r: int(r.get("score") or 0), reverse=True)
    return results


def run_pipeline(
    input_path: Path,
    output_path: Path,
    *,
    min_score: int | None = None,
    actions: set[str] | None = None,
    cities: set[str] | None = None,
    require_phone: bool = False,
) -> int:
    raw_rows = load_records(input_path)
    results = process_records(
        raw_rows,
        min_score=min_score,
        actions=actions,
        cities=cities,
        require_phone=require_phone,
    )

    suffix = output_path.suffix.lower()
    if suffix in {".xlsx", ".xlsm"}:
        save_excel(output_path, results)
    elif suffix == ".csv":
        save_csv(output_path, results)
    else:
        # 默认按 Excel 写，并纠正扩展名
        excel_path = output_path if suffix else output_path.with_suffix(".xlsx")
        if excel_path.suffix.lower() not in {".xlsx", ".xlsm"}:
            excel_path = excel_path.with_suffix(".xlsx")
        save_excel(excel_path, results)
        output_path = excel_path

    return len(results)
