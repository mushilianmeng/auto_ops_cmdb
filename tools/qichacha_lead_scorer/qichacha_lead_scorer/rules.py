"""企查查经营范围 → 跨境专线线索评分规则。

仅基于公开经营范围文本做初筛，不能替代电话确认货量/线路。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class KeywordRule:
    """单条关键词规则。"""

    name: str
    keywords: tuple[str, ...]
    score: int
    tag: str | None = None


# 高相关：进出口权
IMPORT_EXPORT_RULE = KeywordRule(
    name="货物进出口",
    keywords=("货物进出口", "进出口业务", "自营和代理各类商品及技术的进出口"),
    score=2,
    tag="has_import_export",
)

# 技术进出口单独标记，含金量低于货物进出口
TECH_IMPORT_EXPORT_RULE = KeywordRule(
    name="技术进出口",
    keywords=("技术进出口",),
    score=0,
    tag="tech_import_export_only_signal",
)

# 跨境电商/线上销售
ECOMMERCE_RULE = KeywordRule(
    name="电子商务",
    keywords=(
        "电子商务",
        "互联网销售",
        "网上贸易",
        "网络销售",
        "在线销售",
        "跨境电子商务",
    ),
    score=2,
    tag="has_ecommerce",
)

# 适合专线的消费品类
CONSUMER_CATEGORY_RULE = KeywordRule(
    name="消费品类",
    keywords=(
        "服装",
        "服饰",
        "鞋帽",
        "箱包",
        "电子产品",
        "电子元器件",
        "数码产品",
        "通讯设备",
        "手机配件",
        "家居用品",
        "日用百货",
        "工艺品",
        "饰品",
        "化妆品",
        "美妆",
        "玩具",
        "母婴",
        "汽配",
        "汽车配件",
        "五金交电",
    ),
    score=2,
    tag="has_consumer_category",
)

# 履约能力
FULFILLMENT_RULE = KeywordRule(
    name="仓储供应链",
    keywords=("仓储服务", "仓储", "供应链管理", "供应链", "普通货物仓储"),
    score=1,
    tag="has_fulfillment",
)

# 货代/同行
FORWARDER_RULE = KeywordRule(
    name="国际货运代理",
    keywords=(
        "国际货物运输代理",
        "国际货运代理",
        "国内货物运输代理",
        "无船承运",
        "报关",
        "报检",
        "货运代理",
    ),
    score=1,
    tag="is_forwarder_peer",
)

# 弱信号 / 负向
CONSULTING_ONLY_KEYWORDS = (
    "商务信息咨询",
    "企业管理咨询",
    "经济信息咨询",
    "市场营销策划",
    "企业形象策划",
)

TEMPLATE_NOISE_KEYWORDS = (
    "法律、法规、国务院决定规定禁止的不得经营",
    "许可项目",
    "一般项目",
)

POSITIVE_RULES: tuple[KeywordRule, ...] = (
    IMPORT_EXPORT_RULE,
    ECOMMERCE_RULE,
    CONSUMER_CATEGORY_RULE,
    FULFILLMENT_RULE,
    FORWARDER_RULE,
)

# 意向分层阈值
SCORE_PRIORITY = 5
SCORE_MAYBE = 3

ACTION_PRIORITY = "priority_call"
ACTION_MAYBE = "maybe_call"
ACTION_SKIP = "skip"
ACTION_PEER = "peer_pool"


def iter_matched(text: str, keywords: Iterable[str]) -> list[str]:
    """返回在文本中命中的关键词（去重保序）。"""
    matched: list[str] = []
    seen: set[str] = set()
    for kw in keywords:
        if kw and kw in text and kw not in seen:
            matched.append(kw)
            seen.add(kw)
    return matched
