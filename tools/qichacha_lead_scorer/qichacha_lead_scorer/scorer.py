"""基于企查查经营范围的跨境专线线索评分引擎。"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field

from .rules import (
    ACTION_MAYBE,
    ACTION_PEER,
    ACTION_PRIORITY,
    ACTION_SKIP,
    CONSULTING_ONLY_KEYWORDS,
    IMPORT_EXPORT_RULE,
    POSITIVE_RULES,
    SCORE_MAYBE,
    SCORE_PRIORITY,
    TEMPLATE_NOISE_KEYWORDS,
    KeywordRule,
    iter_matched,
)


@dataclass
class ScoreResult:
    company_name: str
    business_scope: str
    score: int
    action: str
    pool: str
    matched_rules: list[str] = field(default_factory=list)
    matched_keywords: list[str] = field(default_factory=list)
    tags: list[str] = field(default_factory=list)
    reasons: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        data = asdict(self)
        data["matched_rules"] = "|".join(self.matched_rules)
        data["matched_keywords"] = "|".join(self.matched_keywords)
        data["tags"] = "|".join(self.tags)
        data["reasons"] = "|".join(self.reasons)
        return data


def _apply_rule(text: str, rule: KeywordRule) -> tuple[int, list[str], str | None]:
    hits = iter_matched(text, rule.keywords)
    if not hits:
        return 0, [], None
    return rule.score, hits, rule.tag


def score_business_scope(
    business_scope: str,
    company_name: str = "",
) -> ScoreResult:
    """对单条经营范围打分并给出动作建议。"""
    text = (business_scope or "").strip()
    name = (company_name or "").strip() or "未知公司"

    if not text:
        return ScoreResult(
            company_name=name,
            business_scope=text,
            score=0,
            action=ACTION_SKIP,
            pool="exclude",
            reasons=["经营范围为空"],
        )

    score = 0
    matched_rules: list[str] = []
    matched_keywords: list[str] = []
    tags: list[str] = []
    reasons: list[str] = []

    for rule in POSITIVE_RULES:
        delta, hits, tag = _apply_rule(text, rule)
        if not hits:
            continue
        score += delta
        matched_rules.append(rule.name)
        matched_keywords.extend(hits)
        if tag:
            tags.append(tag)
        reasons.append(f"+{delta} {rule.name}: {', '.join(hits)}")

    # 负向：像纯咨询壳、无明显货品/进出口
    consulting_hits = iter_matched(text, CONSULTING_ONLY_KEYWORDS)
    has_import_export = IMPORT_EXPORT_RULE.name in matched_rules
    has_goods_signal = any(
        r in matched_rules for r in ("消费品类", "电子商务", "仓储供应链", "国际货运代理")
    )
    if consulting_hits and not has_import_export and not has_goods_signal:
        score -= 2
        tags.append("consulting_heavy")
        reasons.append(f"-2 偏咨询无货品: {', '.join(consulting_hits)}")

    # 负向：模板堆砌过长且正向命中很少
    noise_hits = iter_matched(text, TEMPLATE_NOISE_KEYWORDS)
    if noise_hits and len(text) > 180 and len(matched_rules) <= 1:
        score -= 1
        tags.append("template_noise")
        reasons.append("-1 经营范围疑似模板堆砌")

    is_peer = "is_forwarder_peer" in tags
    has_ecommerce = "has_ecommerce" in tags
    has_category = "has_consumer_category" in tags

    # 分池
    if is_peer and score < SCORE_PRIORITY:
        pool = "peer"
        action = ACTION_PEER
        reasons.append("命中货代/报关，进入同行池")
    elif score >= SCORE_PRIORITY and has_import_export and (has_ecommerce or has_category):
        pool = "direct"
        action = ACTION_PRIORITY
    elif score >= SCORE_PRIORITY:
        pool = "direct"
        action = ACTION_PRIORITY
    elif score >= SCORE_MAYBE:
        pool = "direct"
        action = ACTION_MAYBE
    else:
        pool = "exclude"
        action = ACTION_SKIP

    # 同行但分数很高（货代+电商+品类等）仍标 peer，方便分开话术
    if is_peer and action == ACTION_PRIORITY:
        pool = "peer"
        action = ACTION_PEER
        if "命中货代/报关，进入同行池" not in reasons:
            reasons.append("高分但命中货代特征，按同行池跟进")

    return ScoreResult(
        company_name=name,
        business_scope=text,
        score=score,
        action=action,
        pool=pool,
        matched_rules=matched_rules,
        matched_keywords=_dedupe(matched_keywords),
        tags=_dedupe(tags),
        reasons=reasons,
    )


def _dedupe(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        if item not in seen:
            out.append(item)
            seen.add(item)
    return out
