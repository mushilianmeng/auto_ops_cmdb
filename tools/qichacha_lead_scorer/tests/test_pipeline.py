#!/usr/bin/env python3
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from qichacha_lead_scorer.pipeline import process_records, run_pipeline
from qichacha_lead_scorer.rules import ACTION_PEER, ACTION_PRIORITY, ACTION_SKIP


SAMPLE = ROOT / "sample_api_export.json"


class PipelineTests(unittest.TestCase):
    def test_process_sample_json_rows(self):
        from qichacha_lead_scorer.io_util import load_records

        rows = load_records(SAMPLE)
        results = process_records(rows)
        # digest-002 重复一条，去重后应为 4
        self.assertEqual(len(results), 4)

        by_name = {r["company_name"]: r for r in results}
        self.assertEqual(by_name["深圳某跨境服饰有限公司"]["action"], ACTION_PRIORITY)
        self.assertEqual(by_name["深圳某国际货运代理有限公司"]["action"], ACTION_PEER)
        self.assertEqual(by_name["某商务咨询有限公司"]["action"], ACTION_SKIP)

    def test_city_and_min_score_filter(self):
        from qichacha_lead_scorer.io_util import load_records

        rows = load_records(SAMPLE)
        results = process_records(
            rows,
            cities={"深圳", "广州"},
            min_score=3,
            actions={"priority_call", "maybe_call", "peer_pool"},
            require_phone=True,
        )
        self.assertTrue(results)
        self.assertTrue(all(r["phone"] for r in results))
        self.assertTrue(all(int(r["score"]) >= 3 for r in results))

    def test_run_pipeline_excel(self):
        try:
            import openpyxl  # noqa: F401
        except ImportError:
            self.skipTest("openpyxl not installed")

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "out.xlsx"
            count = run_pipeline(
                SAMPLE,
                out,
                min_score=3,
                actions={"priority_call", "maybe_call", "peer_pool"},
            )
            self.assertGreaterEqual(count, 1)
            self.assertTrue(out.exists())


if __name__ == "__main__":
    unittest.main()
