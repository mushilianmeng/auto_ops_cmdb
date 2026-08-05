#!/usr/bin/env python3
"""评分引擎单测（标准库 unittest，无第三方依赖）。"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from qichacha_lead_scorer import score_business_scope
from qichacha_lead_scorer.rules import ACTION_MAYBE, ACTION_PEER, ACTION_PRIORITY, ACTION_SKIP


class ScoreBusinessScopeTests(unittest.TestCase):
    def test_crossborder_ecommerce_priority(self):
        scope = "货物进出口；电子商务；互联网销售；服装服饰零售；仓储服务"
        result = score_business_scope(scope, "深圳某跨境服饰有限公司")
        self.assertGreaterEqual(result.score, 5)
        self.assertEqual(result.action, ACTION_PRIORITY)
        self.assertEqual(result.pool, "direct")
        self.assertIn("has_ecommerce", result.tags)

    def test_import_export_with_category_maybe_or_priority(self):
        scope = "货物进出口；服装销售；鞋帽零售"
        result = score_business_scope(scope, "广州某服装进出口有限公司")
        self.assertGreaterEqual(result.score, 3)
        self.assertIn(result.action, {ACTION_PRIORITY, ACTION_MAYBE})

    def test_forwarder_goes_peer_pool(self):
        scope = "国际货物运输代理；报关业务；货物进出口"
        result = score_business_scope(scope, "深圳某国际货运代理有限公司")
        self.assertEqual(result.pool, "peer")
        self.assertEqual(result.action, ACTION_PEER)
        self.assertIn("is_forwarder_peer", result.tags)

    def test_consulting_only_skip(self):
        scope = "商务信息咨询；企业管理咨询；市场营销策划"
        result = score_business_scope(scope, "某商务咨询有限公司")
        self.assertLessEqual(result.score, 2)
        self.assertEqual(result.action, ACTION_SKIP)
        self.assertEqual(result.pool, "exclude")

    def test_empty_scope_skip(self):
        result = score_business_scope("", "空壳")
        self.assertEqual(result.score, 0)
        self.assertEqual(result.action, ACTION_SKIP)

    def test_factory_with_import_export(self):
        scope = "塑料制品生产；塑料制品销售；货物进出口"
        result = score_business_scope(scope, "广州某工厂有限公司")
        # 有进出口但无电商/消费品类关键词命中（塑料不算消费品白名单）
        self.assertGreaterEqual(result.score, 2)
        self.assertIn(result.action, {ACTION_MAYBE, ACTION_SKIP, ACTION_PRIORITY})


if __name__ == "__main__":
    unittest.main()
