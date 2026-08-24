#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
移动云 EOS 资源包使用日志造数脚本

默认周期: 2026-01-05 ~ 2026-03-31
资源包累计:
  - 标准存储次数包: 单包 10000 万次 × 6 = 60000 万次 (6 亿次)
  - 对象存储容量包: 单包 512000 GB × 6 = 3072000 GB (3000 TB)
  - 下行流量包:     单包 51200 GB × 6 = 307200 GB (300 TB)
已使用量按总量的 60%~80% 造数（随时间从约 60% 爬升到约 80%）

用法:
  python3 scripts/gen_eos_resource_log.py
  python3 scripts/gen_eos_resource_log.py --start 20260105 --end 20260331 -o /tmp/eos.log
  python3 scripts/gen_eos_resource_log.py --start "2026-01-05 00:00:00" --end "2026-03-31 23:59:59"
  python3 scripts/gen_eos_resource_log.py --usage-start 0.62 --usage-end 0.78 --seed demo
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

# ---------- 资源包规格（累计）----------
PKG_CALL_EACH_WAN = 10000          # 万次 / 单包
PKG_CALL_COUNT = 6
PKG_CALL_TOTAL_WAN = PKG_CALL_EACH_WAN * PKG_CALL_COUNT  # 60000 万次

PKG_CAP_EACH_GB = 512000
PKG_CAP_COUNT = 6
PKG_CAP_TOTAL_GB = PKG_CAP_EACH_GB * PKG_CAP_COUNT       # 3072000 GB

PKG_TRAFFIC_EACH_GB = 51200
PKG_TRAFFIC_COUNT = 6
PKG_TRAFFIC_TOTAL_GB = PKG_TRAFFIC_EACH_GB * PKG_TRAFFIC_COUNT  # 307200 GB

OPS = ("PUT", "HEAD", "GET", "DELETE", "LIST")


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
    raise ValueError("时间格式错误，支持: 20260105 / 2026-01-05 / 2026-01-05 08:00:00")


def end_of_day(dt):
    return dt.replace(hour=23, minute=59, second=59)


def rng(seed, i):
    h = hashlib.md5(("%s:%d" % (seed, i)).encode("utf-8")).hexdigest()
    return int(h[:8], 16) / 4294967295.0


def ts(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def fmt_wan(v):
    """万次，保留 2 位"""
    return "%.2f" % float(v)


def fmt_gb(v):
    return "%.2f" % float(v)


def fmt_tb(gb):
    return "%.2f" % (float(gb) / 1024.0)


def lerp(a, b, t):
    return a + (b - a) * t


def clamp(x, lo, hi):
    return lo if x < lo else hi if x > hi else x


class ResourceState(object):
    """按时间进度计算三类资源包总量/已用（60%~80% 区间内爬升 + 抖动）"""

    def __init__(self, start, end, usage_start, usage_end, seed):
        self.start = start
        self.end = end
        self.usage_start = usage_start
        self.usage_end = usage_end
        self.seed = seed
        self.span = max((end - start).total_seconds(), 1.0)
        self._i = 0

    def _r(self):
        self._i += 1
        return rng(self.seed, self._i)

    def progress(self, dt):
        t = (dt - self.start).total_seconds() / self.span
        return clamp(t, 0.0, 1.0)

    def usage_ratio(self, dt):
        # 主趋势 60%->80%，叠加小幅日抖动，始终落在 [usage_start, usage_end]
        base = lerp(self.usage_start, self.usage_end, self.progress(dt))
        jitter = (self._r() - 0.5) * 0.03  # ±1.5%
        return clamp(base + jitter, self.usage_start, self.usage_end)

    def snapshot(self, dt):
        ratio = self.usage_ratio(dt)
        # 各包使用略有不均，但总和贴近 ratio * total
        call_used = PKG_CALL_TOTAL_WAN * ratio
        cap_used = PKG_CAP_TOTAL_GB * ratio
        traf_used = PKG_TRAFFIC_TOTAL_GB * ratio

        call_pkgs = self._split_packages(
            PKG_CALL_COUNT, PKG_CALL_EACH_WAN, call_used, "call", dt
        )
        cap_pkgs = self._split_packages(
            PKG_CAP_COUNT, PKG_CAP_EACH_GB, cap_used, "cap", dt
        )
        traf_pkgs = self._split_packages(
            PKG_TRAFFIC_COUNT, PKG_TRAFFIC_EACH_GB, traf_used, "traf", dt
        )

        return {
            "ratio": ratio,
            "call_total": PKG_CALL_TOTAL_WAN,
            "call_used": sum(p["used"] for p in call_pkgs),
            "call_remain": PKG_CALL_TOTAL_WAN - sum(p["used"] for p in call_pkgs),
            "call_pkgs": call_pkgs,
            "cap_total": PKG_CAP_TOTAL_GB,
            "cap_used": sum(p["used"] for p in cap_pkgs),
            "cap_remain": PKG_CAP_TOTAL_GB - sum(p["used"] for p in cap_pkgs),
            "cap_pkgs": cap_pkgs,
            "traf_total": PKG_TRAFFIC_TOTAL_GB,
            "traf_used": sum(p["used"] for p in traf_pkgs),
            "traf_remain": PKG_TRAFFIC_TOTAL_GB - sum(p["used"] for p in traf_pkgs),
            "traf_pkgs": traf_pkgs,
        }

    def _split_packages(self, n, each, total_used, kind, dt):
        """把总已用量拆到 n 个单包；单包使用率也落在 60%~80% 附近"""
        avg_ratio = total_used / float(each * n) if each and n else 0.0
        # 单包在均值附近小幅波动，并夹紧到 [usage_start, usage_end]
        ratios = []
        for i in range(n):
            jitter = (rng("%s-%s" % (self.seed, kind), i * 17 + dt.toordinal()) - 0.5) * 0.08
            ratios.append(clamp(avg_ratio + jitter, self.usage_start, self.usage_end))
        # 归一化，使 sum(used) == total_used，同时尽量不越界
        raw = [each * r for r in ratios]
        raw_sum = sum(raw) or 1.0
        scale = total_used / raw_sum
        pkgs = []
        allocated = 0.0
        lo = each * self.usage_start
        hi = each * self.usage_end
        for i in range(n):
            if i == n - 1:
                used = clamp(total_used - allocated, lo, hi)
                # 若受夹紧影响产生漂移，吞在最后一包可调范围内
                used = clamp(used, 0.0, each)
            else:
                used = clamp(raw[i] * scale, lo, hi)
            allocated += used
            active_day = self.start + timedelta(days=i * 14)
            expire_day = active_day + timedelta(days=365)
            pkgs.append({
                "id": i + 1,
                "spec": each,
                "used": used,
                "remain": each - used,
                "ratio": used / each if each else 0.0,
                "active": active_day.strftime("%Y-%m-%d"),
                "expire": expire_day.strftime("%Y-%m-%d"),
                "region": REGION_CN,
            })
        # 二次校准总和
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
                 sample_minutes, verbose_ratio):
        self.start = start
        self.end = end
        self.threads = threads
        self.seed = seed
        self.sample_minutes = sample_minutes
        self.verbose_ratio = verbose_ratio
        self.state = ResourceState(start, end, usage_start, usage_end, seed)
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
        self.emit(dt, "========== EOS resource burn / report start ==========")
        self.emit(dt, "pid=%d python=3.6 period=%s ~ %s" % (
            pid, ts(self.start), ts(self.end)))
        self.emit(dt, "bucket=%s region=%s location=%s storage=%s" % (
            BUCKET, REGION_CN, LOCATION, STORAGE_CLASS))
        self.emit(dt, "endpoint_public=%s" % ENDPOINT)
        self.emit(dt, "bucket_domain=%s" % BUCKET_DOMAIN)
        self.emit(dt, "endpoint_internal=%s" % ENDPOINT_INTERNAL)
        self.emit(dt, "threads=%d seed=%s" % (self.threads, self.seed))
        self.emit(dt, "PACKAGE_PLAN calls: 单包=%d万次 × %d = 累计=%d万次 (%.0f亿次)" % (
            PKG_CALL_EACH_WAN, PKG_CALL_COUNT, PKG_CALL_TOTAL_WAN,
            PKG_CALL_TOTAL_WAN / 10000.0))
        self.emit(dt, "PACKAGE_PLAN capacity: 单包=%dGB × %d = 累计=%dGB (%sTB)" % (
            PKG_CAP_EACH_GB, PKG_CAP_COUNT, PKG_CAP_TOTAL_GB,
            fmt_tb(PKG_CAP_TOTAL_GB)))
        self.emit(dt, "PACKAGE_PLAN traffic: 单包=%dGB × %d = 累计=%dGB (%sTB)" % (
            PKG_TRAFFIC_EACH_GB, PKG_TRAFFIC_COUNT, PKG_TRAFFIC_TOTAL_GB,
            fmt_tb(PKG_TRAFFIC_TOTAL_GB)))
        self.emit(dt, "USAGE_POLICY target_ratio=%.0f%%~%.0f%% (current~%.1f%%)" % (
            self.state.usage_start * 100, self.state.usage_end * 100, snap["ratio"] * 100))

    def emit_package_report(self, dt, tag="RESOURCE"):
        snap = self.state.snapshot(dt)
        self.emit(dt, "----- %s SNAPSHOT bucket=%s -----" % (tag, BUCKET))

        # 次数包汇总
        self.emit(dt,
            "%s CALL_PKG total=%s万次 used=%s万次 remain=%s万次 usage=%.2f%% "
            "(单包=%d万次 × %d包)" % (
                tag,
                fmt_wan(snap["call_total"]),
                fmt_wan(snap["call_used"]),
                fmt_wan(snap["call_remain"]),
                snap["call_used"] / snap["call_total"] * 100,
                PKG_CALL_EACH_WAN, PKG_CALL_COUNT,
            ))
        for p in snap["call_pkgs"]:
            self.emit(dt,
                "%s CALL_PKG#%d region=%s spec=%s万次 used=%s万次 remain=%s万次 "
                "usage=%.2f%% active=%s expire=%s status=生效中" % (
                    tag, p["id"], p["region"],
                    fmt_wan(p["spec"]), fmt_wan(p["used"]), fmt_wan(p["remain"]),
                    p["ratio"] * 100, p["active"], p["expire"],
                ))

        # 容量包汇总
        self.emit(dt,
            "%s CAP_PKG total=%sGB(%sTB) used=%sGB(%sTB) remain=%sGB(%sTB) "
            "usage=%.2f%% (单包=%dGB × %d包)" % (
                tag,
                fmt_gb(snap["cap_total"]), fmt_tb(snap["cap_total"]),
                fmt_gb(snap["cap_used"]), fmt_tb(snap["cap_used"]),
                fmt_gb(snap["cap_remain"]), fmt_tb(snap["cap_remain"]),
                snap["cap_used"] / snap["cap_total"] * 100,
                PKG_CAP_EACH_GB, PKG_CAP_COUNT,
            ))
        for p in snap["cap_pkgs"]:
            self.emit(dt,
                "%s CAP_PKG#%d region=%s spec=%sGB used=%sGB remain=%sGB "
                "usage=%.2f%% active=%s expire=%s status=生效中" % (
                    tag, p["id"], p["region"],
                    fmt_gb(p["spec"]), fmt_gb(p["used"]), fmt_gb(p["remain"]),
                    p["ratio"] * 100, p["active"], p["expire"],
                ))

        # 下行流量包汇总
        self.emit(dt,
            "%s TRAFFIC_PKG total=%sGB(%sTB) used=%sGB(%sTB) remain=%sGB(%sTB) "
            "usage=%.2f%% (单包=%dGB × %d包)" % (
                tag,
                fmt_gb(snap["traf_total"]), fmt_tb(snap["traf_total"]),
                fmt_gb(snap["traf_used"]), fmt_tb(snap["traf_used"]),
                fmt_gb(snap["traf_remain"]), fmt_tb(snap["traf_remain"]),
                snap["traf_used"] / snap["traf_total"] * 100,
                PKG_TRAFFIC_EACH_GB, PKG_TRAFFIC_COUNT,
            ))
        for p in snap["traf_pkgs"]:
            self.emit(dt,
                "%s TRAFFIC_PKG#%d region=%s spec=%sGB used=%sGB remain=%sGB "
                "usage=%.2f%% active=%s expire=%s status=生效中" % (
                    tag, p["id"], p["region"],
                    fmt_gb(p["spec"]), fmt_gb(p["used"]), fmt_gb(p["remain"]),
                    p["ratio"] * 100, p["active"], p["expire"],
                ))

        self.emit(dt,
            "%s SUMMARY overall_usage~%.2f%% calls_used=%s万次 cap_used=%sGB "
            "traffic_used=%sGB endpoint=%s" % (
                tag, snap["ratio"] * 100,
                fmt_wan(snap["call_used"]),
                fmt_gb(snap["cap_used"]),
                fmt_gb(snap["traf_used"]),
                ENDPOINT,
            ))
        return snap

    def emit_ops_burst(self, dt, day_index):
        """每个采样点穿插一批操作日志"""
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

            # 偶发错误
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

        # 进度行（兼容旧格式）
        elapsed = max((dt - self.start).total_seconds(), 1.0)
        qps = self.calls / elapsed * (0.9 + self.r() * 0.25)
        # 放大显示感：采样点累计 objects
        show_objects = max(self.objects, int(self.calls / 4))
        self.emit(dt, "STAT objects=%d calls=%d errors=%d ~%.0f calls/s threads_active=%d" % (
            show_objects, self.calls, self.errors, max(qps, 1), self.threads))
        self.emit(dt, "STAT io stored~%.2fGB downloaded~%.2fGB bucket=%s" % (
            self.bytes_stored / 1024.0 / 1024.0 / 1024.0,
            self.bytes_down / 1024.0 / 1024.0 / 1024.0,
            BUCKET,
        ))

    def emit_monthly_rollup(self, dt):
        snap = self.emit_package_report(dt, tag="MONTHLY")
        month_key = dt.strftime("%Y-%m")
        self.emit(dt, "MONTHLY ROLLUP month=%s bucket=%s location=%s" % (
            month_key, BUCKET, LOCATION))
        self.emit(dt, "MONTHLY ROLLUP 标准存储次数包 总量=%s万次 已使用=%s万次 使用率=%.2f%%" % (
            fmt_wan(snap["call_total"]), fmt_wan(snap["call_used"]),
            snap["call_used"] / snap["call_total"] * 100))
        self.emit(dt, "MONTHLY ROLLUP 对象存储容量包 总量=%sGB(%sTB) 已使用=%sGB(%sTB) 使用率=%.2f%%" % (
            fmt_gb(snap["cap_total"]), fmt_tb(snap["cap_total"]),
            fmt_gb(snap["cap_used"]), fmt_tb(snap["cap_used"]),
            snap["cap_used"] / snap["cap_total"] * 100))
        self.emit(dt, "MONTHLY ROLLUP 对象存储下行流量包 总量=%sGB(%sTB) 已使用=%sGB(%sTB) 使用率=%.2f%%" % (
            fmt_gb(snap["traf_total"]), fmt_tb(snap["traf_total"]),
            fmt_gb(snap["traf_used"]), fmt_tb(snap["traf_used"]),
            snap["traf_used"] / snap["traf_total"] * 100))

    def build(self):
        cur = self.start
        self.write_banner(cur)
        self.emit_package_report(cur, tag="RESOURCE")

        for t in range(1, min(self.threads, 16) + 1):
            self.emit(cur + timedelta(seconds=t),
                      "[thread-%02d] worker online conn=https keep-alive endpoint=%s" % (
                          t, ENDPOINT))

        day_index = 0
        last_month = None
        sample = timedelta(minutes=self.sample_minutes)
        cur = self.start + timedelta(minutes=5)

        while cur <= self.end:
            day_index += 1
            self.emit_ops_burst(cur, day_index)

            # 每 6 个采样点打一次完整资源包快照
            if day_index % 6 == 0:
                self.emit_package_report(cur, tag="RESOURCE")

            # 心跳
            if day_index % 3 == 0:
                uptime = int((cur - self.start).total_seconds())
                self.emit(cur, "HEARTBEAT uptime=%ds rss~%dMB fd=%d conn_pool=%d/%d" % (
                    uptime,
                    90 + int(self.r() * 140),
                    220 + int(self.r() * 500),
                    int(self.threads * (0.65 + self.r() * 0.35)),
                    self.threads,
                ))

            # 月初/月末月报
            month = cur.strftime("%Y-%m")
            if last_month is None:
                last_month = month
            if month != last_month:
                # 上个月最后时刻月报
                month_end = cur.replace(day=1) - timedelta(seconds=1)
                if month_end >= self.start:
                    self.emit_monthly_rollup(month_end)
                last_month = month

            # 每天一次简要配额行（保证“总量/已使用”高频可见）
            if cur.hour in (0, 8, 14, 20) or day_index % 4 == 1:
                snap = self.state.snapshot(cur)
                self.emit(cur,
                    "QUOTA calls_total=%s万次 calls_used=%s万次 | "
                    "cap_total=%sGB cap_used=%sGB | "
                    "traffic_total=%sGB traffic_used=%sGB | usage~%.1f%%" % (
                        fmt_wan(snap["call_total"]), fmt_wan(snap["call_used"]),
                        fmt_gb(snap["cap_total"]), fmt_gb(snap["cap_used"]),
                        fmt_gb(snap["traf_total"]), fmt_gb(snap["traf_used"]),
                        snap["ratio"] * 100,
                    ))

            cur += sample

        # 周期结束月报 + 终态
        self.emit_monthly_rollup(self.end)
        final = self.emit_package_report(self.end, tag="FINAL")
        self.emit(self.end, "========== EOS resource burn / report end ==========")
        self.emit(self.end,
            "FINAL_CHECK period=%s~%s calls_used=%s/%s万次(%.1f%%) "
            "cap_used=%s/%sGB(%.1f%%) traffic_used=%s/%sGB(%.1f%%)" % (
                self.start.strftime("%Y%m%d"),
                self.end.strftime("%Y%m%d"),
                fmt_wan(final["call_used"]), fmt_wan(final["call_total"]),
                final["call_used"] / final["call_total"] * 100,
                fmt_gb(final["cap_used"]), fmt_gb(final["cap_total"]),
                final["cap_used"] / final["cap_total"] * 100,
                fmt_gb(final["traf_used"]), fmt_gb(final["traf_total"]),
                final["traf_used"] / final["traf_total"] * 100,
            ))
        return self.lines


def main():
    p = argparse.ArgumentParser(description="造 EOS 资源包使用复杂日志（含总量/已使用量）")
    p.add_argument("--start", default="20260105",
                   help="起始时间，默认 20260105")
    p.add_argument("--end", default="20260331",
                   help="结束时间，默认 20260331")
    p.add_argument("-o", "--output", default="-",
                   help="输出文件，默认 stdout")
    p.add_argument("--threads", type=int, default=64, help="模拟线程数")
    p.add_argument("--seed", default="yunchenkejieos001-20260105",
                   help="随机种子，相同可复现")
    p.add_argument("--usage-start", type=float, default=0.60,
                   help="期初使用率，默认 0.60")
    p.add_argument("--usage-end", type=float, default=0.80,
                   help="期末使用率，默认 0.80")
    p.add_argument("--sample-minutes", type=int, default=180,
                   help="采样间隔分钟，默认 180（3小时一条业务块，周期日志更可控）")
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
    # 若只给日期，结束日接到 23:59:59
    if len(str(args.end).strip()) <= 10:
        end = end_of_day(end)
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
    )
    lines = builder.build()
    text = "\n".join(lines) + "\n"

    if args.output == "-":
        sys.stdout.write(text)
    else:
        with open(args.output, "w") as f:
            f.write(text)
        # 抽样校验使用率
        final_lines = [ln for ln in lines if "FINAL_CHECK" in ln]
        print("lines=%d -> %s" % (len(lines), args.output), file=sys.stderr)
        if final_lines:
            print(final_lines[-1], file=sys.stderr)


if __name__ == "__main__":
    main()
