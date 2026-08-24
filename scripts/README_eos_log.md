# EOS 资源包造日志脚本

脚本：`gen_eos_resource_log.py`

按移动云 EOS 资源包信息生成复杂使用日志，周期默认 `20260105` ~ `20260331`。

## 资源包累计规格

| 类型 | 单包 | 包数 | 累计总量 |
|------|------|------|----------|
| 标准存储次数包 | 10000 万次 | 6 | 60000 万次（6 亿次） |
| 对象存储容量包 | 512000 GB | 6 | 3072000 GB（3000 TB） |
| 下行流量包 | 51200 GB | 6 | 307200 GB（300 TB） |

已使用量按总量的 **60%~80%** 造数（随时间从约 60% 爬升到约 80%），日志中同时输出：

- 累计总量 / 已使用 / 剩余 / 使用率
- 每个单包的规格、已用、剩余、生效/到期

## 用法

```bash
# 默认周期，输出到 stdout
python3 scripts/gen_eos_resource_log.py

# 指定时间并写文件
python3 scripts/gen_eos_resource_log.py \
  --start 20260105 --end 20260331 \
  -o /tmp/eos_resource.log

# 更密采样（默认 180 分钟）
python3 scripts/gen_eos_resource_log.py --sample-minutes 60 -o /tmp/eos.log

# 使用率区间可调
python3 scripts/gen_eos_resource_log.py --usage-start 0.62 --usage-end 0.78
```

## 日志关键字

- `PACKAGE_PLAN`：三类包规划总量
- `RESOURCE` / `FINAL`：资源包快照（总量+已用）
- `QUOTA`：简要配额行
- `MONTHLY ROLLUP`：月度汇总
- `STAT`：调用进度
- `FINAL_CHECK`：周期结束校验行
