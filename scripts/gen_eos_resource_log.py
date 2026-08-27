#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
移动云 EOS 资源包使用日志造数脚本

按费用中心订单为准（示例：下行流量包）:
  - 订单编号: MOP-T-26010448398352
  - 订单创建时间: 2026-01-04 17:13:03
  - 开通时间: 2026-01-04 17:13:04
  - 到期时间: 2026-04-04 17:13:04
  - 商品: 对象存储包 / 对象存储下行流量包(GB): 51200
  - 计费方式: 包月计费（项目期 3 个月）
  - 每月额度（6 个同类包合计）:
      * 标准存储次数: 6 亿次 = 60000 万次（单包 10000 万次 × 6）
      * 存储容量:     3 PB   = 3072000 GB（单包 512000 GB × 6）
      * 下行流量:     300 TB = 307200 GB（单包 51200 GB × 6）
  - 已使用量：每个月 4 号新账期从 0 重置，当月内缓慢增长到约 60%~80%

用法:
  python3 scripts/gen_eos_resource_log.py
  python3 scripts/gen_eos_resource_log.py \\
    --start "2026-01-04 17:13:04" --end "2026-03-31 23:59:59" -o /tmp/eos.log
"""
from __future__ import print_function

import argparse
import hashlib
import sys
from datetime import datetime, timedelta

# ---------- 控制台/桶信息 ----------
BUCKET = "yunchenkejieos001"
REGION_CN = "西南-重庆2"
LOCATION = "chongqing3"
ENDPOINT = "eos-chongqing-3.cmecloud.cn"
ENDPOINT_INTERNAL = "eos-chongqing-3-internal.cmecloud.cn"
BUCKET_DOMAIN = "yunchenkejieos001.eos-chongqing-3.cmecloud.cn"
STORAGE_CLASS = "标准存储"
ACCOUNT = "yunchenkeji"

# ---------- 订购 / 订单（以费用中心订单详情为准）----------
ORDER_NO = "MOP-T-26010448398352"
ORDER_BATCH_NO = "MOP-O-26010441749060"
ORDER_CREATE = datetime(2026, 1, 4, 17, 13, 3)
ORDER_START = datetime(2026, 1, 4, 17, 13, 4)   # 开通时间
FINAL_EXPIRE = datetime(2026, 4, 4, 17, 13, 4)  # 到期时间
PROJECT_MONTHS = 3
ORDER_TYPE = "新建"
ORDER_STATUS = "开通成功"
BILLING_METHOD = "包月计费"
PRODUCT_NAME = "对象存储包"
# 截图中的下行流量包订单行
TRAFFIC_RESOURCE_ID = "18733c89fdcf499eb252e0dfffd6f931"
TRAFFIC_SUBSCRIBE_ID = "10062663572"
TRAFFIC_UNIT_PRICE = 19497.0
TRAFFIC_TOTAL_AMOUNT = 58491.0  # 19497 × 3 个月

# ---------- 每月资源包规格（不是项目累计）----------
PKG_CALL_EACH_WAN = 10000          # 万次 / 单包
PKG_CALL_COUNT = 6
PKG_CALL_MONTH_WAN = PKG_CALL_EACH_WAN * PKG_CALL_COUNT  # 60000 万次 = 6 亿次/月

PKG_CAP_EACH_GB = 512000
PKG_CAP_COUNT = 6
PKG_CAP_MONTH_GB = PKG_CAP_EACH_GB * PKG_CAP_COUNT       # 3072000 GB = 3 PB/月

PKG_TRAFFIC_EACH_GB = 51200
PKG_TRAFFIC_COUNT = 6
PKG_TRAFFIC_MONTH_GB = PKG_TRAFFIC_EACH_GB * PKG_TRAFFIC_COUNT  # 307200 GB = 300 TB/月

OPS = ("PUT", "HEAD", "GET", "DELETE", "LIST")


def derive_id(base, n, kind="res"):
    """同规格多包时，#1 用订单真实 ID，其余由真实 ID 派生（可复现）。"""
    if n == 1:
        return base
    h = hashlib.md5(("%s:%s:%d" % (base, kind, n)).encode("utf-8")).hexdigest()
    if kind == "sub":
        # 订购关系 ID 保持相近数字形态
        try:
            return str(int(base) + n - 1)
        except ValueError:
            return h[:11]
    return h


def parse_time(s):
    s = str(s).strip()
    for fmt in (
        "%Y%m%d",
        "%Y-%m-%d",
        "%Y%m%d%H%M%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
    ):
        try:
            dt = datetime.strptime(s, fmt)
            if fmt in ("%Y%m%d", "%Y-%m-%d"):
                return dt.replace(hour=0, minute=0, second=0)
            return dt
        except ValueError:
            pass
    raise ValueError("时间格式错误，支持: 20260105 / 2026-01-05 / 2026-01-04 17:15:00")


def end_of_day(dt):
    return dt.replace(hour=23, minute=59, second=59)


def rng(seed, i):
    h = hashlib.md5(("%s:%d" % (seed, i)).encode("utf-8")).hexdigest()
    return int(h[:8], 16) / 4294967295.0


def ts(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def fmt_wan(v):
    return "%.2f" % float(v)


def fmt_gb(v):
    return "%.2f" % float(v)


def fmt_tb(gb):
    return "%.2f" % (float(gb) / 1024.0)


def fmt_pb(gb):
    # 业务口径: 1024GB=1TB, 1000TB=1PB（3072000GB -> 3000TB -> 3PB）
    return "%.2f" % (float(gb) / 1024.0 / 1000.0)


def lerp(a, b, t):
    return a + (b - a) * t


def clamp(x, lo, hi):
    return lo if x < lo else hi if x > hi else x


def build_billing_cycles(order_start, months):
    """每月一账期，包有效期刚好一个月；第 months 期到期日 = order_start + months 月"""
    cycles = []
    for i in range(months):
        # 按「同日同时刻」进一个月，避免日历差异；用 replace 处理跨月
        y = order_start.year
        m = order_start.month + i
        while m > 12:
            y += 1
            m -= 12
        start = order_start.replace(year=y, month=m)
        y2 = order_start.year
        m2 = order_start.month + i + 1
        while m2 > 12:
            y2 += 1
            m2 -= 12
        end = order_start.replace(year=y2, month=m2)
        cycles.append({
            "index": i + 1,
            "start": start,
            "end": end,
            "label": "M%d" % (i + 1),
            "auto_renew": i < months - 1,
        })
    return cycles


class ResourceState(object):
    """按「当前账期（一个月）」计算当月额度总量/已用（60%~80%）"""

    def __init__(self, cycles, usage_start, usage_end, seed, order_start, final_expire):
        self.cycles = cycles
        self.usage_start = usage_start
        self.usage_end = usage_end
        self.seed = seed
        self.order_start = order_start
        self.final_expire = final_expire
        self._i = 0

    def _r(self):
        self._i += 1
        return rng(self.seed, self._i)

    def cycle_for(self, dt):
        for c in self.cycles:
            if c["start"] <= dt < c["end"]:
                return c
        # 边界：刚好到期时刻算最后一期
        if dt >= self.cycles[-1]["end"]:
            return self.cycles[-1]
        return self.cycles[0]

    def usage_ratio(self, dt):
        """账期内从 0 缓慢增长到 usage_end；每月 4 号换期后重新从 0 开始。"""
        c = self.cycle_for(dt)
        span = max((c["end"] - c["start"]).total_seconds(), 1.0)
        t = clamp((dt - c["start"]).total_seconds() / span, 0.0, 1.0)
        # 缓慢增长：前慢后稍快的平滑曲线，避免线性太“假”
        # ease-in-out 近似: 3t^2 - 2t^3
        eased = t * t * (3.0 - 2.0 * t)
        base = lerp(self.usage_start, self.usage_end, eased)
        jitter = (self._r() - 0.5) * 0.02  # ±1%
        lo = min(self.usage_start, self.usage_end)
        hi = max(self.usage_start, self.usage_end)
        return clamp(base + jitter, lo, hi)

    def snapshot(self, dt):
        c = self.cycle_for(dt)
        ratio = self.usage_ratio(dt)
        call_used = PKG_CALL_MONTH_WAN * ratio
        cap_used = PKG_CAP_MONTH_GB * ratio
        traf_used = PKG_TRAFFIC_MONTH_GB * ratio

        call_pkgs = self._split_packages(
            PKG_CALL_COUNT, PKG_CALL_EACH_WAN, call_used, "call", c, dt
        )
        cap_pkgs = self._split_packages(
            PKG_CAP_COUNT, PKG_CAP_EACH_GB, cap_used, "cap", c, dt
        )
        traf_pkgs = self._split_packages(
            PKG_TRAFFIC_COUNT, PKG_TRAFFIC_EACH_GB, traf_used, "traf", c, dt
        )

        return {
            "cycle": c,
            "ratio": ratio,
            "call_total": PKG_CALL_MONTH_WAN,
            "call_used": sum(p["used"] for p in call_pkgs),
            "call_remain": PKG_CALL_MONTH_WAN - sum(p["used"] for p in call_pkgs),
            "call_pkgs": call_pkgs,
            "cap_total": PKG_CAP_MONTH_GB,
            "cap_used": sum(p["used"] for p in cap_pkgs),
            "cap_remain": PKG_CAP_MONTH_GB - sum(p["used"] for p in cap_pkgs),
            "cap_pkgs": cap_pkgs,
            "traf_total": PKG_TRAFFIC_MONTH_GB,
            "traf_used": sum(p["used"] for p in traf_pkgs),
            "traf_remain": PKG_TRAFFIC_MONTH_GB - sum(p["used"] for p in traf_pkgs),
            "traf_pkgs": traf_pkgs,
        }

    def _split_packages(self, n, each, total_used, kind, cycle, dt):
        avg_ratio = total_used / float(each * n) if each and n else 0.0
        ratios = []
        for i in range(n):
            jitter = (rng("%s-%s-M%d" % (self.seed, kind, cycle["index"]),
                          i * 17 + dt.toordinal()) - 0.5) * 0.08
            ratios.append(clamp(avg_ratio + jitter, 0.0, max(self.usage_start, self.usage_end)))
        raw = [each * r for r in ratios]
        raw_sum = sum(raw) or 1.0
        scale = total_used / raw_sum
        pkgs = []
        allocated = 0.0
        # 允许月初接近 0；月末落在 usage_end 附近
        lo = max(0.0, each * min(self.usage_start, self.usage_end) - each * 0.01)
        hi = each * max(self.usage_start, self.usage_end)
        # 控制台口径：生效=订购时间，到期=自动续订最终到期 2026-04-04
        active = self.order_start.strftime("%Y-%m-%d %H:%M:%S")
        expire = self.final_expire.strftime("%Y-%m-%d %H:%M:%S")
        for i in range(n):
            if i == n - 1:
                used = clamp(total_used - allocated, 0.0, each)
                used = clamp(used, lo, hi) if total_used > 0 else 0.0
            else:
                used = clamp(raw[i] * scale, lo, hi) if total_used > 0 else 0.0
            allocated += used
            pkgs.append({
                "id": i + 1,
                "spec": each,
                "used": used,
                "remain": each - used,
                "ratio": used / each if each else 0.0,
                "active": active,
                "expire": expire,
                "region": REGION_CN,
                "cycle": cycle["label"],
                "validity": "1个月(自动续订)",
                "auto_renew": "是" if cycle["auto_renew"] else "否(末期)",
            })
        # 月初总量接近 0 时不再二次校准拉高
        if total_used <= 0.01:
            for p in pkgs:
                p["used"] = 0.0
                p["remain"] = each
                p["ratio"] = 0.0
            return pkgs
        drift = total_used - sum(p["used"] for p in pkgs)
        if pkgs and abs(drift) > 0.01:
            for p in reversed(pkgs):
                neu = clamp(p["used"] + drift, lo, hi)
                applied = neu - p["used"]
                p["used"] = neu
                p["remain"] = each - p["used"]
                p["ratio"] = p["used"] / each if each else 0.0
                drift -= applied
                if abs(drift) <= 0.01:
                    break
        return pkgs


class LogBuilder(object):
    def __init__(self, start, end, threads, seed, usage_start, usage_end,
                 sample_minutes, verbose_ratio, order_start, final_expire):
        self.start = start
        self.end = end
        self.threads = threads
        self.seed = seed
        self.sample_minutes = sample_minutes
        self.verbose_ratio = verbose_ratio
        self.order_start = order_start
        self.final_expire = final_expire
        self.cycles = build_billing_cycles(order_start, PROJECT_MONTHS)
        self.state = ResourceState(
            self.cycles, usage_start, usage_end, seed, order_start, final_expire)
        self.lines = []
        self.i = 0
        self.objects = 0
        self.calls = 0
        self.errors = 0
        self.bytes_down = 0
        self.bytes_stored = 0

    def r(self):
        self.i += 1
        return rng(self.seed, self.i)

    def emit(self, dt, msg):
        self.lines.append("%s %s" % (ts(dt), msg))

    def key_name(self, wid, seq):
        nano = 1786500000000000000 + int(self.r() * 9e13) + seq * 17
        rnd = int(self.r() * 32000) + wid
        return "burn/%d-%d-%d.bin" % (wid, nano, rnd)

    def write_banner(self, dt):
        pid = 12000 + int(self.r() * 40000)
        snap = self.state.snapshot(dt)
        c = snap["cycle"]
        self.emit(dt, "========== EOS resource burn / report start ==========")
        self.emit(dt, "pid=%d python=3.6 log_period=%s ~ %s" % (
            pid, ts(self.start), ts(self.end)))
        self.emit(dt, "bucket=%s region=%s location=%s storage=%s" % (
            BUCKET, REGION_CN, LOCATION, STORAGE_CLASS))
        self.emit(dt, "endpoint_public=%s" % ENDPOINT)
        self.emit(dt, "bucket_domain=%s" % BUCKET_DOMAIN)
        self.emit(dt, "endpoint_internal=%s" % ENDPOINT_INTERNAL)
        self.emit(dt, "ORDER order_no=%s batch_no=%s account=%s type=%s status=%s" % (
            ORDER_NO, ORDER_BATCH_NO, ACCOUNT, ORDER_TYPE, ORDER_STATUS))
        self.emit(dt, "ORDER create_time=%s active=%s expire=%s billing=%s product=%s" % (
            ts(ORDER_CREATE), ts(self.order_start), ts(self.final_expire),
            BILLING_METHOD, PRODUCT_NAME))
        self.emit(dt, "ORDER traffic_cfg=对象存储下行流量包(GB):%d "
                   "resource_id=%s subscribe_id=%s unit_price=%.0f元/月 total_amount=%.2f "
                   "months=%d" % (
            PKG_TRAFFIC_EACH_GB, TRAFFIC_RESOURCE_ID, TRAFFIC_SUBSCRIBE_ID,
            TRAFFIC_UNIT_PRICE, TRAFFIC_TOTAL_AMOUNT, PROJECT_MONTHS))
        self.emit(dt, "ORDER note=开通/到期以订单为准; 包月计费; 每月4号进入下一计费周期用量从0累计")
        self.emit(dt, "BILLING note=资源数为每月额度; 单包规格见 PACKAGE_PLAN; 订单到期=%s" % (
            ts(self.final_expire)))
        for cy in self.cycles:
            self.emit(dt, "BILLING_CYCLE %s active=%s expire=%s auto_renew=%s" % (
                cy["label"], ts(cy["start"]), ts(cy["end"]),
                "yes" if cy["auto_renew"] else "no"))
        self.emit(dt, "PACKAGE_PLAN_MONTHLY calls: 单包=%d万次 × %d = 每月=%d万次 (%.0f亿次/月)" % (
            PKG_CALL_EACH_WAN, PKG_CALL_COUNT, PKG_CALL_MONTH_WAN,
            PKG_CALL_MONTH_WAN / 10000.0))
        self.emit(dt, "PACKAGE_PLAN_MONTHLY capacity: 单包=%dGB × %d = 每月=%dGB (%sTB/%sPB /月)" % (
            PKG_CAP_EACH_GB, PKG_CAP_COUNT, PKG_CAP_MONTH_GB,
            fmt_tb(PKG_CAP_MONTH_GB), fmt_pb(PKG_CAP_MONTH_GB)))
        self.emit(dt, "PACKAGE_PLAN_MONTHLY traffic: 单包=%dGB × %d = 每月=%dGB (%sTB/月)" % (
            PKG_TRAFFIC_EACH_GB, PKG_TRAFFIC_COUNT, PKG_TRAFFIC_MONTH_GB,
            fmt_tb(PKG_TRAFFIC_MONTH_GB)))
        self.emit(dt, "CURRENT_CYCLE %s active=%s expire=%s" % (
            c["label"], ts(c["start"]), ts(c["end"])))
        self.emit(dt, "USAGE_POLICY monthly_reset_on=每月4号新账期从0开始; "
                   "grow_to=%.0f%%~%.0f%% (current~%.1f%%)" % (
            max(self.state.usage_start, 0) * 100,
            self.state.usage_end * 100,
            snap["ratio"] * 100))
        self.emit(dt, "USAGE_POLICY note=每个计费周期独立累计使用量，跨月不结转")

    def emit_package_report(self, dt, tag="RESOURCE"):
        snap = self.state.snapshot(dt)
        c = snap["cycle"]
        self.emit(dt, "----- %s SNAPSHOT bucket=%s cycle=%s (valid 1 month) -----" % (
            tag, BUCKET, c["label"]))
        self.emit(dt, "%s CYCLE active=%s expire=%s auto_renew=%s final_expire=%s" % (
            tag, ts(c["start"]), ts(c["end"]),
            "yes" if c["auto_renew"] else "no", ts(self.final_expire)))

        self.emit(dt,
            "%s CALL_PKG scope=monthly total=%s万次(6亿次/月) used=%s万次 remain=%s万次 "
            "usage=%.2f%% (单包=%d万次 × %d包, 有效期=1个月)" % (
                tag,
                fmt_wan(snap["call_total"]),
                fmt_wan(snap["call_used"]),
                fmt_wan(snap["call_remain"]),
                snap["call_used"] / snap["call_total"] * 100,
                PKG_CALL_EACH_WAN, PKG_CALL_COUNT,
            ))
        for p in snap["call_pkgs"]:
            self.emit(dt,
                "%s CALL_PKG#%d cycle=%s region=%s spec=%s万次 used=%s万次 remain=%s万次 "
                "usage=%.2f%% active=%s expire=%s validity=%s auto_renew=%s status=生效中" % (
                    tag, p["id"], p["cycle"], p["region"],
                    fmt_wan(p["spec"]), fmt_wan(p["used"]), fmt_wan(p["remain"]),
                    p["ratio"] * 100, p["active"], p["expire"],
                    p["validity"], p["auto_renew"],
                ))

        self.emit(dt,
            "%s CAP_PKG scope=monthly total=%sGB(%sTB/%sPB /月) used=%sGB(%sTB) "
            "remain=%sGB(%sTB) usage=%.2f%% (单包=%dGB × %d包, 有效期=1个月)" % (
                tag,
                fmt_gb(snap["cap_total"]), fmt_tb(snap["cap_total"]), fmt_pb(snap["cap_total"]),
                fmt_gb(snap["cap_used"]), fmt_tb(snap["cap_used"]),
                fmt_gb(snap["cap_remain"]), fmt_tb(snap["cap_remain"]),
                snap["cap_used"] / snap["cap_total"] * 100,
                PKG_CAP_EACH_GB, PKG_CAP_COUNT,
            ))
        for p in snap["cap_pkgs"]:
            self.emit(dt,
                "%s CAP_PKG#%d cycle=%s region=%s spec=%sGB used=%sGB remain=%sGB "
                "usage=%.2f%% active=%s expire=%s validity=%s auto_renew=%s status=生效中" % (
                    tag, p["id"], p["cycle"], p["region"],
                    fmt_gb(p["spec"]), fmt_gb(p["used"]), fmt_gb(p["remain"]),
                    p["ratio"] * 100, p["active"], p["expire"],
                    p["validity"], p["auto_renew"],
                ))

        self.emit(dt,
            "%s TRAFFIC_PKG scope=monthly total=%sGB(%sTB/月) used=%sGB(%sTB) "
            "remain=%sGB(%sTB) usage=%.2f%% (单包=%dGB × %d包, 有效期=1个月)" % (
                tag,
                fmt_gb(snap["traf_total"]), fmt_tb(snap["traf_total"]),
                fmt_gb(snap["traf_used"]), fmt_tb(snap["traf_used"]),
                fmt_gb(snap["traf_remain"]), fmt_tb(snap["traf_remain"]),
                snap["traf_used"] / snap["traf_total"] * 100,
                PKG_TRAFFIC_EACH_GB, PKG_TRAFFIC_COUNT,
            ))
        for p in snap["traf_pkgs"]:
            rid = derive_id(TRAFFIC_RESOURCE_ID, p["id"], "res")
            sid = derive_id(TRAFFIC_SUBSCRIBE_ID, p["id"], "sub")
            self.emit(dt,
                "%s TRAFFIC_PKG#%d cycle=%s region=%s product=%s "
                "cfg=对象存储下行流量包(GB):%s "
                "resource_id=%s subscribe_id=%s order_no=%s "
                "spec=%sGB used=%sGB remain=%sGB usage=%.2f%% "
                "active=%s expire=%s billing=%s status=%s" % (
                    tag, p["id"], p["cycle"], p["region"], PRODUCT_NAME,
                    fmt_gb(p["spec"]),
                    rid, sid, ORDER_NO,
                    fmt_gb(p["spec"]), fmt_gb(p["used"]), fmt_gb(p["remain"]),
                    p["ratio"] * 100, p["active"], p["expire"],
                    BILLING_METHOD, ORDER_STATUS,
                ))

        self.emit(dt,
            "%s SUMMARY cycle=%s overall_usage~%.2f%% calls_used=%s万次 "
            "cap_used=%sGB traffic_used=%sGB endpoint=%s" % (
                tag, c["label"], snap["ratio"] * 100,
                fmt_wan(snap["call_used"]),
                fmt_gb(snap["cap_used"]),
                fmt_gb(snap["traf_used"]),
                ENDPOINT,
            ))
        return snap

    def emit_ops_burst(self, dt, day_index):
        burst = 8 + int(self.r() * 20)
        for n in range(burst):
            wid = 1 + int(self.r() * self.threads)
            name = self.key_name(wid, day_index * 10000 + n)
            op = OPS[int(self.r() * len(OPS))]
            lag = 5 + int(self.r() * 60)
            self.calls += 1

            if op == "PUT":
                size_mb = [1, 4, 16, 64, 128, 256][int(self.r() * 6)]
                self.bytes_stored += size_mb * 1024 * 1024
                self.objects += 1
                if self.r() < self.verbose_ratio:
                    self.emit(dt, "[thread-%02d] PUT ok s3://%s/%s size=%dMB latency=%dms" % (
                        wid, BUCKET, name, size_mb, lag))
            elif op == "GET":
                size_mb = [16, 64, 128, 256, 512][int(self.r() * 5)]
                self.bytes_down += size_mb * 1024 * 1024
                if self.r() < self.verbose_ratio:
                    self.emit(dt, "[thread-%02d] GET ok s3://%s/%s bytes=%d latency=%dms" % (
                        wid, BUCKET, name, size_mb * 1024 * 1024, lag))
            elif op == "DELETE":
                if self.r() < self.verbose_ratio:
                    self.emit(dt, "[thread-%02d] DELETE ok s3://%s/%s latency=%dms" % (
                        wid, BUCKET, name, lag))
            elif op == "LIST":
                if self.r() < self.verbose_ratio:
                    self.emit(dt, "[thread-%02d] LIST ok prefix=burn/ max-keys=%d" % (
                        wid, 1 + int(self.r() * 100)))
            else:
                if self.r() < self.verbose_ratio:
                    self.emit(dt, "[thread-%02d] HEAD ok s3://%s/%s latency=%dms" % (
                        wid, BUCKET, name, lag))

            if self.r() < 0.012:
                self.errors += 1
                code = [429, 500, 503, 408][int(self.r() * 4)]
                self.emit(dt, "[thread-%02d] WARN %s %s -> HTTP %d, retry 1/3" % (
                    wid, op, name, code))
                if self.r() < 0.3:
                    self.emit(dt, "[thread-%02d] ERROR %s %s retry exhausted" % (
                        wid, op, name))
                    self.errors += 1
                else:
                    self.emit(dt, "[thread-%02d] INFO %s %s retry ok" % (wid, op, name))

        elapsed = max((dt - self.start).total_seconds(), 1.0)
        qps = self.calls / elapsed * (0.9 + self.r() * 0.25)
        show_objects = max(self.objects, int(self.calls / 4))
        c = self.state.cycle_for(dt)
        self.emit(dt, "STAT cycle=%s objects=%d calls=%d errors=%d ~%.0f calls/s threads_active=%d" % (
            c["label"], show_objects, self.calls, self.errors, max(qps, 1), self.threads))
        self.emit(dt, "STAT io stored~%.2fGB downloaded~%.2fGB bucket=%s" % (
            self.bytes_stored / 1024.0 / 1024.0 / 1024.0,
            self.bytes_down / 1024.0 / 1024.0 / 1024.0,
            BUCKET,
        ))

    def emit_cycle_rollup(self, dt, tag="CYCLE"):
        snap = self.emit_package_report(dt, tag=tag)
        c = snap["cycle"]
        self.emit(dt, "%s ROLLUP cycle=%s active=%s expire=%s bucket=%s" % (
            tag, c["label"], ts(c["start"]), ts(c["end"]), BUCKET))
        self.emit(dt, "%s ROLLUP 标准存储次数包(每月) 总量=%s万次(6亿次) 已使用=%s万次 使用率=%.2f%%" % (
            tag, fmt_wan(snap["call_total"]), fmt_wan(snap["call_used"]),
            snap["call_used"] / snap["call_total"] * 100))
        self.emit(dt, "%s ROLLUP 对象存储容量包(每月) 总量=%sGB(%sPB) 已使用=%sGB 使用率=%.2f%%" % (
            tag, fmt_gb(snap["cap_total"]), fmt_pb(snap["cap_total"]),
            fmt_gb(snap["cap_used"]),
            snap["cap_used"] / snap["cap_total"] * 100))
        self.emit(dt, "%s ROLLUP 对象存储下行流量包(每月) 总量=%sGB(%sTB) 已使用=%sGB 使用率=%.2f%%" % (
            tag, fmt_gb(snap["traf_total"]), fmt_tb(snap["traf_total"]),
            fmt_gb(snap["traf_used"]),
            snap["traf_used"] / snap["traf_total"] * 100))
        return snap

    def build(self):
        cur = self.start
        self.write_banner(cur)
        self.emit_package_report(cur, tag="RESOURCE")

        for t in range(1, min(self.threads, 16) + 1):
            self.emit(cur + timedelta(seconds=t),
                      "[thread-%02d] worker online conn=https keep-alive endpoint=%s" % (
                          t, ENDPOINT))

        day_index = 0
        last_cycle = None
        sample = timedelta(minutes=self.sample_minutes)
        cur = self.start + timedelta(minutes=5)

        while cur <= self.end:
            day_index += 1
            c = self.state.cycle_for(cur)

            # 跨账期：上一期收官 + 续订生效
            if last_cycle is None:
                last_cycle = c["index"]
            if c["index"] != last_cycle:
                prev = self.cycles[last_cycle - 1]
                edge = prev["end"] - timedelta(seconds=1)
                if edge >= self.start:
                    self.emit_cycle_rollup(edge, tag="CYCLE_END")
                self.emit(cur, "AUTORENEW previous=%s -> current=%s new_active=%s new_expire=%s "
                               "final_expire=%s" % (
                                   prev["label"], c["label"], ts(c["start"]), ts(c["end"]),
                                   ts(self.final_expire)))
                self.emit(cur, "USAGE_RESET cycle=%s reason=新计费周期开始(每月4号) "
                               "calls_used=0 cap_used=0 traffic_used=0 "
                               "note=使用量从0重新累计" % c["label"])
                self.emit_package_report(cur, tag="RENEW")
                last_cycle = c["index"]

            self.emit_ops_burst(cur, day_index)

            if day_index % 6 == 0:
                self.emit_package_report(cur, tag="RESOURCE")

            if day_index % 3 == 0:
                uptime = int((cur - self.start).total_seconds())
                self.emit(cur, "HEARTBEAT cycle=%s uptime=%ds rss~%dMB fd=%d conn_pool=%d/%d" % (
                    c["label"], uptime,
                    90 + int(self.r() * 140),
                    220 + int(self.r() * 500),
                    int(self.threads * (0.65 + self.r() * 0.35)),
                    self.threads,
                ))

            if cur.hour in (0, 8, 14, 20) or day_index % 4 == 1:
                snap = self.state.snapshot(cur)
                self.emit(cur,
                    "QUOTA scope=monthly cycle=%s "
                    "calls_total=%s万次 calls_used=%s万次 | "
                    "cap_total=%sGB cap_used=%sGB | "
                    "traffic_total=%sGB traffic_used=%sGB | "
                    "usage~%.1f%% pkg_expire=%s final_expire=%s" % (
                        snap["cycle"]["label"],
                        fmt_wan(snap["call_total"]), fmt_wan(snap["call_used"]),
                        fmt_gb(snap["cap_total"]), fmt_gb(snap["cap_used"]),
                        fmt_gb(snap["traf_total"]), fmt_gb(snap["traf_used"]),
                        snap["ratio"] * 100,
                        ts(self.final_expire),
                        ts(self.final_expire),
                    ))

            cur += sample

        self.emit_cycle_rollup(self.end, tag="FINAL")
        final = self.state.snapshot(self.end)
        self.emit(self.end, "========== EOS resource burn / report end ==========")
        self.emit(self.end,
            "FINAL_CHECK order=%s final_expire=%s "
            "current_cycle=%s calls_used=%s/%s万次(%.1f%%) "
            "cap_used=%s/%sGB(%.1f%%) traffic_used=%s/%sGB(%.1f%%) "
            "note=以上为当月额度使用率(包有效期1个月)" % (
                ts(self.order_start), ts(self.final_expire),
                final["cycle"]["label"],
                fmt_wan(final["call_used"]), fmt_wan(final["call_total"]),
                final["call_used"] / final["call_total"] * 100,
                fmt_gb(final["cap_used"]), fmt_gb(final["cap_total"]),
                final["cap_used"] / final["cap_total"] * 100,
                fmt_gb(final["traf_used"]), fmt_gb(final["traf_total"]),
                final["traf_used"] / final["traf_total"] * 100,
            ))
        return self.lines


def main():
    p = argparse.ArgumentParser(
        description="造 EOS 每月资源包使用日志（包有效期1个月，含总量/已使用量）")
    p.add_argument("--start", default="2026-01-04 17:13:04",
                   help="日志起始时间，默认开通时间 2026-01-04 17:13:04")
    p.add_argument("--end", default="20260331",
                   help="日志结束时间，默认 20260331")
    p.add_argument("--order-start", default="2026-01-04 17:13:04",
                   help="资源包开通时间（订单开通时间）")
    p.add_argument("--final-expire", default="2026-04-04 17:13:04",
                   help="订单到期时间，默认 2026-04-04 17:13:04")
    p.add_argument("-o", "--output", default="-",
                   help="输出文件，默认 stdout")
    p.add_argument("--threads", type=int, default=64, help="模拟线程数")
    p.add_argument("--seed", default="yunchenkejieos001-MOP-T-26010448398352",
                   help="随机种子，相同可复现")
    p.add_argument("--usage-start", type=float, default=0.0,
                   help="当月期初使用率，默认 0（每月4号重置从0开始）")
    p.add_argument("--usage-end", type=float, default=0.75,
                   help="当月期末使用率，默认 0.75（落在60%%~80%%）")
    p.add_argument("--sample-minutes", type=int, default=180,
                   help="采样间隔分钟，默认 180")
    p.add_argument("--verbose-ratio", type=float, default=0.15,
                   help="详细请求日志比例 0~1")
    args = p.parse_args()

    if not (0.0 <= args.usage_start <= 1.0 and 0.0 <= args.usage_end <= 1.0):
        print("usage-start/end 需在 0~1 之间", file=sys.stderr)
        sys.exit(2)
    if args.usage_start > args.usage_end:
        print("usage-start 不能大于 usage-end", file=sys.stderr)
        sys.exit(2)

    start = parse_time(args.start)
    end = parse_time(args.end)
    if len(str(args.end).strip()) <= 10:
        end = end_of_day(end)
    order_start = parse_time(args.order_start)
    final_expire = parse_time(args.final_expire)
    if end < start:
        print("end 不能早于 start", file=sys.stderr)
        sys.exit(2)

    builder = LogBuilder(
        start=start,
        end=end,
        threads=args.threads,
        seed=args.seed,
        usage_start=args.usage_start,
        usage_end=args.usage_end,
        sample_minutes=args.sample_minutes,
        verbose_ratio=args.verbose_ratio,
        order_start=order_start,
        final_expire=final_expire,
    )
    lines = builder.build()
    text = "\n".join(lines) + "\n"

    if args.output == "-":
        sys.stdout.write(text)
    else:
        with open(args.output, "w") as f:
            f.write(text)
        final_lines = [ln for ln in lines if "FINAL_CHECK" in ln]
        print("lines=%d -> %s" % (len(lines), args.output), file=sys.stderr)
        if final_lines:
            print(final_lines[-1], file=sys.stderr)


if __name__ == "__main__":
    main()
