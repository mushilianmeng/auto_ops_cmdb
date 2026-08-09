# 企查查经营范围 → 跨境专线线索初筛

纯本地处理工具：读取你**已合法导出**的企业 JSON/CSV/Excel，按经营范围规则打分，导出优先外呼名单。

> 不包含、也不会协助实现带 Cookie 请求第三方商业站点私有接口的爬虫。

## 评分规则

| 信号 | 分 |
|------|----|
| 货物进出口 | +2 |
| 电子商务 / 互联网销售等 | +2 |
| 消费品类（服装/3C/家居等） | +2 |
| 仓储 / 供应链 | +1 |
| 国际货运代理 / 报关等 | +1，并标同行 |
| 偏咨询且无货品/进出口 | -2 |
| 疑似模板堆砌 | -1 |

- `score >= 5` → `priority_call`
- `3–4` → `maybe_call`
- `<= 2` → `skip`
- 命中货代特征 → `peer_pool`

**重要：列表里如果没有「经营范围」，无法有效打分。**  
请确保导出字段包含 `business_scope` / `经营范围`。

## 安装

```bash
cd tools/qichacha_lead_scorer
pip install -r requirements.txt   # 仅 Excel 读写需要 openpyxl
```

## 用法

```bash
# 单条演示
python3 -m qichacha_lead_scorer --demo \
  --company "深圳某跨境服饰有限公司" \
  --scope-text "货物进出口；电子商务；服装服饰零售；仓储服务"

# 处理接口风格 JSON（含 data.rows）并导出 Excel
python3 process_export.py \
  -i sample_api_export.json \
  -o 跨境电商客户测试.xlsx

# 只要深圳/广州、有电话、可跟进线索
python3 process_export.py \
  -i sample_api_export.json \
  -o hot.xlsx \
  --cities 深圳,广州 \
  --min-score 3 \
  --actions priority_call,maybe_call,peer_pool \
  --require-phone
```

## 输入字段兼容

| 用途 | 兼容字段 |
|------|----------|
| 公司名 | `company_real_name` / `company_name` / `企业名称` |
| 经营范围 | `business_scope` / `经营范围` / `company_business` |
| 去重键 | `company_name_digest` / `统一社会信用代码` / 公司名 |
| 电话 | `company_phone` / `电话` |
| 地址 | `company_address` / `地址` |

也支持直接喂接口完整 JSON：`{"status":0,"data":{"rows":[...]}}`

## 输出列

公司名称、法人、状态、成立日期、注册资本、城市、地址、电话、邮箱、网址、经营范围、意向分、动作、分池、命中规则、命中关键词、标签、评分说明。

## 测试

```bash
cd tools/qichacha_lead_scorer
python3 tests/test_scorer.py
python3 tests/test_pipeline.py
```

## 和你原脚本的关系

| 原脚本步骤 | 本工具 |
|------------|--------|
| Cookie + POST 第三方私有接口翻页 | **不支持**（请用官方导出） |
| 去重 | ✅ |
| 写 Excel | ✅ |
| 按跨境专线规则判断值不值得打 | ✅ 新增 |
