# 企查查经营范围 → 跨境专线线索初筛

纯标准库实现，把前面梳理的规则做成可批量跑的评分器。

## 做什么

输入公司名 + 经营范围（企查查导出 CSV），输出：

| 字段 | 含义 |
|------|------|
| `score` | 意向分 |
| `action` | `priority_call` / `maybe_call` / `peer_pool` / `skip` |
| `pool` | `direct` 直客 / `peer` 同行 / `exclude` 排除 |
| `matched_rules` | 命中的规则名 |
| `matched_keywords` | 命中的关键词 |
| `tags` | 结构化标签 |
| `reasons` | 加减分说明 |

## 评分规则（与口头方案一致）

| 信号 | 分 |
|------|----|
| 货物进出口 | +2 |
| 电子商务 / 互联网销售等 | +2 |
| 消费品类（服装/3C/家居等） | +2 |
| 仓储 / 供应链 | +1 |
| 国际货运代理 / 报关等 | +1，并标同行 |
| 偏咨询且无货品/进出口 | -2 |
| 疑似模板堆砌 | -1 |

分层：

- `score >= 5` → `priority_call`（优先外呼）
- `3–4` → `maybe_call`
- `<= 2` → `skip`
- 命中货代特征 → `peer_pool`（话术按同行）

## 用法

```bash
# 单条演示
python -m qichacha_lead_scorer --demo \
  --company "深圳某跨境服饰有限公司" \
  --scope-text "货物进出口；电子商务；服装服饰零售；仓储服务"

# 批量 CSV
cd tools/qichacha_lead_scorer
python -m qichacha_lead_scorer \
  -i sample_input.csv \
  -o scored_output.csv

# 只保留优先外呼 + 可跟进
python -m qichacha_lead_scorer \
  -i sample_input.csv \
  -o scored_hot.csv \
  --min-score 3 \
  --actions priority_call,maybe_call,peer_pool
```

输入 CSV 表头支持：

- 公司名：`company_name` / `企业名称` / `公司名称` / `名称`
- 经营范围：`business_scope` / `经营范围`

也可用 `--name-field` / `--scope-field` 指定。

## 代码调用

```python
from qichacha_lead_scorer import score_business_scope

result = score_business_scope(
    "货物进出口；电子商务；服装销售",
    company_name="示例公司",
)
print(result.score, result.action, result.reasons)
```

## 测试

```bash
cd tools/qichacha_lead_scorer
python tests/test_scorer.py
```

## 注意

- 经营范围是「可以做」不是「正在做」，本工具只做初筛。
- 不要用本工具去绕过平台限制抓取数据；请使用你已合法导出的公开企业信息。
- 外呼前仍建议用 20 秒确认：目的国、周货量、现有渠道。
