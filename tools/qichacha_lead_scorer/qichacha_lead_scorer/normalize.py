"""把常见导出字段归一成统一结构。"""

from __future__ import annotations

from typing import Any


NAME_FIELDS = (
    "company_real_name",
    "company_name",
    "企业名称",
    "公司名称",
    "名称",
    "name",
)

SCOPE_FIELDS = (
    "business_scope",
    "company_business",
    "n_company_business",
    "经营范围",
    "scope",
)

DIGEST_FIELDS = (
    "company_name_digest",
    "digest",
    "credit_code",
    "统一社会信用代码",
)

PHONE_FIELDS = ("company_phone", "phone", "电话", "联系电话")
EMAIL_FIELDS = ("company_email", "email", "邮箱")
ADDRESS_FIELDS = ("company_address", "address", "地址", "注册地址")
STATUS_FIELDS = ("company_status", "status", "状态", "登记状态")
LEGAL_FIELDS = ("legal_person", "法人", "法定代表人")
DATE_FIELDS = ("establish_date", "成立日期", "成立时间")
CAPITAL_FIELDS = ("capital", "注册资本")
WEBSITE_FIELDS = ("web_site_url", "website", "网址", "官网")
CITY_FIELDS = ("city", "城市")


def _first(row: dict[str, Any], fields: tuple[str, ...]) -> str:
    lower_map = {str(k).strip().lower(): v for k, v in row.items() if k is not None}
    for key in fields:
        if key in row and row[key] not in (None, ""):
            return str(row[key]).strip()
        lk = key.lower()
        if lk in lower_map and lower_map[lk] not in (None, ""):
            return str(lower_map[lk]).strip()
    return ""


def normalize_company(row: dict[str, Any]) -> dict[str, str]:
    """归一化单条企业记录。"""
    name = _first(row, NAME_FIELDS)
    address = _first(row, ADDRESS_FIELDS)
    city = _first(row, CITY_FIELDS) or infer_city(address)
    digest = _first(row, DIGEST_FIELDS) or name

    return {
        "digest": digest,
        "company_name": name,
        "legal_person": _first(row, LEGAL_FIELDS),
        "company_status": _first(row, STATUS_FIELDS),
        "establish_date": _first(row, DATE_FIELDS),
        "capital": _first(row, CAPITAL_FIELDS),
        "address": address,
        "city": city,
        "phone": _first(row, PHONE_FIELDS),
        "email": _first(row, EMAIL_FIELDS),
        "website": _first(row, WEBSITE_FIELDS),
        "business_scope": _first(row, SCOPE_FIELDS),
    }


def infer_city(address: str) -> str:
    if not address:
        return ""
    for city in ("深圳市", "广州市", "深圳", "广州"):
        if city in address:
            return "深圳" if "深圳" in city else "广州"
    return ""


def dedupe_companies(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    """按 digest / 公司名去重，保留后出现的记录。"""
    unique: dict[str, dict[str, str]] = {}
    for row in rows:
        key = row.get("digest") or row.get("company_name")
        if not key:
            continue
        unique[key] = row
    return list(unique.values())
