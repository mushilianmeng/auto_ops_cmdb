#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EOS 资源使用日志造数 v2 —— 基于《对象存储-20260601-20260826-资源使用情况》

数据文件: scripts/data/eos_packages_20260601_20260826.json（37 条资源包）

口径:
  - 日志周期默认 2026-06-01 ~ 2026-08-26
  - 主账期锚点: 2026-06-03 16:46:12（首批订购），每月 3 号换期，用量从 0 重置
  - 到期/计划退订以表内「退订时间」字段为准（使用中包默认到期 2026-09-03，计划 8/31 暂停退订）
  - 真实订单号、资源ID、暂停/恢复/退订事件写入日志
  - 已使用量按「当时生效资源包合计额度」的 0→60%~80% 缓慢增长

用法:
  python3 scripts/gen_eos_resource_log_v2.py -o /tmp/eos_v2.log
  python3 scripts/gen_eos_resource_log_v2.py --start 20260601 --end 20260826 -o /tmp/eos_v2.log
"""
from __future__ import print_function

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timedelta

BUCKET = "yunchenkejieos001"
REGION_CN = "西南-重庆2"
LOCATION = "chongqing3"
ENDPOINT = "eos-chongqing-3.cmecloud.cn"
ENDPOINT_INTERNAL = "eos-chongqing-3-internal.cmecloud.cn"
BUCKET_DOMAIN = "yunchenkejieos001.eos-chongqing-3.cmecloud.cn"
ACCOUNT = "yunchenkeji"

# 主订购账期锚点（容量包首单）
ANCHOR = datetime(2026, 1, 4, 17, 13, 4)  # 占位，启动时用数据覆盖
DEFAULT_DATA = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "data",
    "eos_packages_20260601_20260826.json",
)


def parse_time(s):
    if s is None:
        return None
    s = str(s).strip()
    if not s or s in ("无", "None", "-"):
        return None
    for fmt in (
        "%Y%m%d",
        "%Y-%m-%d",
        "%Y%m%d%H%M%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
        "%Y/%m/%d",
    ):
        try:
            dt = datetime.strptime(s, fmt)
            if fmt in ("%Y%m%d", "%Y-%m-%d", "%Y/%m/%d"):
                return dt.replace(hour=0, minute=0, second=0)
            return dt
        except ValueError:
            pass
    raise ValueError("bad time: %r" % s)


def end_of_day(dt):
    return dt.replace(hour=23, minute=59, second=59)


def ts(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def rng(seed, i):
    h = hashlib.md5(("%s:%d" % (seed, i)).encode("utf-8")).hexdigest()
    return int(h[:8], 16) / 4294967295.0


def lerp(a, b, t):
    return a + (b - a) * t


def clamp(x, lo, hi):
    return lo if x < lo else hi if x > hi else x


def fmt_num(v):
    return "%.2f" % float(v)


def fmt_tb(gb):
    return "%.2f" % (float(gb) / 1024.0)


def fmt_pb(gb):
    return "%.2f" % (float(gb) / 1024.0 / 1000.0)


def classify(name):
    if "下行" in name:
        return "traffic"
    if "次数" in name:
        return "calls"
    return "capacity"


def parse_unsubscribe(raw, order_time):
    """返回 (unsubscribe_dt or None, planned_expire or None, note)"""
    if raw is None:
        return None, None, ""
    s = str(raw).strip()
    if not s or s == "无":
        return None, None, s
    # 纯时间戳 = 已退订
    try:
        return parse_time(s), None, s
    except ValueError:
        pass
    # 未退订，默认YYYY-MM-DD HH:MM:SS到期。将在2026/8/31暂停业务并退订
    m = re.search(r"默认\s*([0-9:\- /]+)\s*到期", s)
    planned = None
    if m:
        try:
            planned = parse_time(m.group(1).strip())
        except ValueError:
            planned = None
    if planned is None and order_time is not None:
        # 默认 +3 个月
        y, mth = order_time.year, order_time.month + 3
        while mth > 12:
            y += 1
            mth -= 12
        planned = order_time.replace(year=y, month=mth)
    return None, planned, s


def load_packages(path):
    rows = json.load(open(path, "r"))
    pkgs = []
    for r in rows:
        order_time = parse_time(r.get("订购时间"))
        pause = parse_time(r.get("暂停时间")) if r.get("暂停时间") not in (None, "无") else None
        resume = parse_time(r.get("恢复时间")) if r.get("恢复时间") not in (None, "无") else None
        unsub, planned, note = parse_unsubscribe(r.get("退订时间"), order_time)
        pkgs.append({
            "idx": r.get("序号"),
            "order_no": r.get("对应订单号"),
            "resource_id": r.get("资源ID"),
            "name": r.get("资源包名称"),
            "kind": classify(r.get("资源包名称") or ""),
            "amount": float(r.get("资源数") or 0),
            "order_time": order_time,
            "pause": pause,
            "resume": resume,
            "unsubscribe": unsub,
            "planned_expire": planned,
            "status_raw": r.get("状态"),
            "note": note,
        })
    return pkgs


def add_months(dt, n):
    y = dt.year
    m = dt.month + n
    while m > 12:
        y += 1
        m -= 12
    while m < 1:
        y -= 1
        m += 12
    return dt.replace(year=y, month=m)


def build_cycles(anchor, months=4):
    cycles = []
    for i in range(months):
        start = add_months(anchor, i)
        end = add_months(anchor, i + 1)
        cycles.append({
            "index": i + 1,
            "label": "M%d" % (i + 1),
            "start": start,
            "end": end,
        })
    return cycles


class Inventory(object):
    def __init__(self, pkgs, cycles, usage_start, usage_end, seed):
        self.pkgs = pkgs
        self.cycles = cycles
        self.usage_start = usage_start
        self.usage_end = usage_end
        self.seed = seed
        self._i = 0

    def _r(self):
        self._i += 1
        return rng(self.seed, self._i)

    def cycle_for(self, dt):
        for c in self.cycles:
            if c["start"] <= dt < c["end"]:
                return c
        if dt < self.cycles[0]["start"]:
            return None
        return self.cycles[-1]

    def is_active(self, p, dt):
        if p["order_time"] is None or dt < p["order_time"]:
            return False
        if p["unsubscribe"] is not None and dt >= p["unsubscribe"]:
            return False
        # 暂停窗口内视为不可用（不计入额度）
        if p["pause"] and p["resume"]:
            if p["pause"] <= dt < p["resume"]:
                return False
        elif p["pause"] and not p["resume"]:
            if dt >= p["pause"]:
                return False
        return True

    def is_paused(self, p, dt):
        if not p["pause"]:
            return False
        if p["resume"]:
            return p["pause"] <= dt < p["resume"]
        return dt >= p["pause"]

    def package_ratio(self, p, dt):
        """单包使用率：从订购/当月账期起点从 0 增长到 usage_end。"""
        c = self.cycle_for(dt)
        if c is None:
            return 0.0
        # 本账期内该包生效起点
        start = max(c["start"], p["order_time"] or c["start"])
        if dt < start:
            return 0.0
        span = max((c["end"] - start).total_seconds(), 1.0)
        t = clamp((dt - start).total_seconds() / span, 0.0, 1.0)
        eased = t * t * (3.0 - 2.0 * t)
        base = lerp(self.usage_start, self.usage_end, eased)
        jitter = (self._r() - 0.5) * 0.02
        return clamp(base + jitter, 0.0, max(self.usage_end, self.usage_start))

    def snapshot(self, dt):
        active = [p for p in self.pkgs if self.is_active(p, dt)]
        paused = [p for p in self.pkgs if self.is_paused(p, dt) and
                  p["order_time"] and dt >= p["order_time"] and
                  (p["unsubscribe"] is None or dt < p["unsubscribe"])]
        by = {"capacity": [], "calls": [], "traffic": []}
        for p in active:
            ratio = self.package_ratio(p, dt)
            used = p["amount"] * ratio
            by[p["kind"]].append({
                "pkg": p,
                "used": used,
                "remain": p["amount"] - used,
                "ratio": ratio,
            })

        def agg(kind):
            items = by[kind]
            total = sum(x["pkg"]["amount"] for x in items)
            used = sum(x["used"] for x in items)
            return {
                "total": total,
                "used": used,
                "remain": total - used,
                "ratio": (used / total) if total else 0.0,
                "items": items,
                "count": len(items),
            }

        return {
            "dt": dt,
            "cycle": self.cycle_for(dt),
            "active_count": len(active),
            "paused_count": len(paused),
            "capacity": agg("capacity"),
            "calls": agg("calls"),
            "traffic": agg("traffic"),
            "paused": paused,
        }


class LogBuilder(object):
    def __init__(self, pkgs, start, end, sample_minutes, usage_start, usage_end,
                 seed, verbose_ratio):
        self.pkgs = pkgs
        self.start = start
        self.end = end
        self.sample_minutes = sample_minutes
        self.verbose_ratio = verbose_ratio
        self.seed = seed
        # 账期锚点：最早订购时间
        ordered = sorted([p["order_time"] for p in pkgs if p["order_time"]])
        self.anchor = ordered[0] if ordered else datetime(2026, 6, 3, 16, 46, 12)
        self.cycles = build_cycles(self.anchor, months=4)
        self.inv = Inventory(pkgs, self.cycles, usage_start, usage_end, seed)
        self.lines = []
        self.i = 0
        self.objects = 0
        self.calls_ops = 0
        self.errors = 0

    def r(self):
        self.i += 1
        return rng(self.seed, self.i)

    def emit(self, dt, msg):
        self.lines.append("%s %s" % (ts(dt), msg))

    def write_banner(self, dt):
        snap = self.inv.snapshot(max(dt, self.anchor))
        self.emit(dt, "========== EOS resource usage log v2 start ==========")
        self.emit(dt, "source=对象存储-20260601-20260826-资源使用情况 packages=%d" % len(self.pkgs))
        self.emit(dt, "bucket=%s account=%s region=%s location=%s" % (
            BUCKET, ACCOUNT, REGION_CN, LOCATION))
        self.emit(dt, "endpoint=%s bucket_domain=%s" % (ENDPOINT, BUCKET_DOMAIN))
        self.emit(dt, "period=%s ~ %s anchor=%s" % (ts(self.start), ts(self.end), ts(self.anchor)))
        self.emit(dt, "POLICY monthly_reset=账期按订购日+N月; 用量从0缓慢增长到约%.0f%%~%.0f%%" % (
            self.inv.usage_start * 100, self.inv.usage_end * 100))
        for c in self.cycles:
            self.emit(dt, "BILLING_CYCLE %s active=%s expire=%s" % (
                c["label"], ts(c["start"]), ts(c["end"])))
        # 包清单摘要
        for p in self.pkgs:
            expire = p["unsubscribe"] or p["planned_expire"]
            self.emit(dt,
                "PKG_CATALOG #%d kind=%s order_no=%s resource_id=%s amount=%s "
                "order_time=%s pause=%s resume=%s unsub_or_expire=%s status=%s" % (
                    p["idx"], p["kind"], p["order_no"], p["resource_id"],
                    fmt_num(p["amount"]),
                    ts(p["order_time"]) if p["order_time"] else "-",
                    ts(p["pause"]) if p["pause"] else "无",
                    ts(p["resume"]) if p["resume"] else "无",
                    ts(expire) if expire else "-",
                    p["status_raw"],
                ))

    def emit_quota(self, dt, tag="RESOURCE"):
        snap = self.inv.snapshot(dt)
        c = snap["cycle"]
        clabel = c["label"] if c else "NONE"
        self.emit(dt, "----- %s SNAPSHOT cycle=%s active_pkgs=%d paused_pkgs=%d -----" % (
            tag, clabel, snap["active_count"], snap["paused_count"]))

        calls = snap["calls"]
        self.emit(dt,
            "%s CALL_PKG scope=active_sum total=%s万次 used=%s万次 remain=%s万次 "
            "usage=%.2f%% packages=%d" % (
                tag, fmt_num(calls["total"]), fmt_num(calls["used"]),
                fmt_num(calls["remain"]), calls["ratio"] * 100, calls["count"]))
        for it in calls["items"]:
            p = it["pkg"]
            exp = p["unsubscribe"] or p["planned_expire"]
            self.emit(dt,
                "%s CALL_PKG#%d order_no=%s resource_id=%s spec=%s万次 "
                "used=%s万次 remain=%s万次 usage=%.2f%% active=%s expire=%s status=%s" % (
                    tag, p["idx"], p["order_no"], p["resource_id"],
                    fmt_num(p["amount"]), fmt_num(it["used"]), fmt_num(it["remain"]),
                    it["ratio"] * 100,
                    ts(p["order_time"]), ts(exp) if exp else "-",
                    p["status_raw"],
                ))

        cap = snap["capacity"]
        self.emit(dt,
            "%s CAP_PKG scope=active_sum total=%sGB(%sTB/%sPB) used=%sGB(%sTB) "
            "remain=%sGB usage=%.2f%% packages=%d" % (
                tag, fmt_num(cap["total"]), fmt_tb(cap["total"]), fmt_pb(cap["total"]),
                fmt_num(cap["used"]), fmt_tb(cap["used"]),
                fmt_num(cap["remain"]), cap["ratio"] * 100, cap["count"]))
        for it in cap["items"]:
            p = it["pkg"]
            exp = p["unsubscribe"] or p["planned_expire"]
            self.emit(dt,
                "%s CAP_PKG#%d order_no=%s resource_id=%s spec=%sGB "
                "used=%sGB remain=%sGB usage=%.2f%% active=%s expire=%s status=%s" % (
                    tag, p["idx"], p["order_no"], p["resource_id"],
                    fmt_num(p["amount"]), fmt_num(it["used"]), fmt_num(it["remain"]),
                    it["ratio"] * 100,
                    ts(p["order_time"]), ts(exp) if exp else "-",
                    p["status_raw"],
                ))

        traf = snap["traffic"]
        self.emit(dt,
            "%s TRAFFIC_PKG scope=active_sum total=%sGB(%sTB) used=%sGB(%sTB) "
            "remain=%sGB usage=%.2f%% packages=%d" % (
                tag, fmt_num(traf["total"]), fmt_tb(traf["total"]),
                fmt_num(traf["used"]), fmt_tb(traf["used"]),
                fmt_num(traf["remain"]), traf["ratio"] * 100, traf["count"]))
        for it in traf["items"]:
            p = it["pkg"]
            exp = p["unsubscribe"] or p["planned_expire"]
            self.emit(dt,
                "%s TRAFFIC_PKG#%d order_no=%s resource_id=%s "
                "cfg=对象存储下行流量包(GB):%s "
                "used=%sGB remain=%sGB usage=%.2f%% active=%s expire=%s status=%s" % (
                    tag, p["idx"], p["order_no"], p["resource_id"],
                    fmt_num(p["amount"]),
                    fmt_num(it["used"]), fmt_num(it["remain"]),
                    it["ratio"] * 100,
                    ts(p["order_time"]), ts(exp) if exp else "-",
                    p["status_raw"],
                ))

        self.emit(dt,
            "%s SUMMARY cycle=%s calls_used=%s/%s万次 cap_used=%s/%sGB "
            "traffic_used=%s/%sGB overall~%.1f%%" % (
                tag, clabel,
                fmt_num(calls["used"]), fmt_num(calls["total"]),
                fmt_num(cap["used"]), fmt_num(cap["total"]),
                fmt_num(traf["used"]), fmt_num(traf["total"]),
                ((calls["ratio"] + cap["ratio"] + traf["ratio"]) / 3.0) * 100
                if (calls["total"] or cap["total"] or traf["total"]) else 0.0,
            ))
        return snap

    def emit_ops(self, dt):
        burst = 6 + int(self.r() * 14)
        for _ in range(burst):
            self.calls_ops += 1
            if self.r() < self.verbose_ratio:
                wid = 1 + int(self.r() * 32)
                op = ("PUT", "GET", "HEAD", "DELETE", "LIST")[int(self.r() * 5)]
                self.emit(dt, "[thread-%02d] %s ok bucket=%s endpoint=%s" % (
                    wid, op, BUCKET, ENDPOINT))
            if self.r() < 0.01:
                self.errors += 1
                self.emit(dt, "WARN soft-throttle endpoint=%s http=429" % ENDPOINT)
        snap = self.inv.snapshot(dt)
        self.emit(dt,
            "QUOTA cycle=%s calls_total=%s万次 calls_used=%s万次 | "
            "cap_total=%sGB cap_used=%sGB | "
            "traffic_total=%sGB traffic_used=%sGB | usage~%.1f%%" % (
                snap["cycle"]["label"] if snap["cycle"] else "NONE",
                fmt_num(snap["calls"]["total"]), fmt_num(snap["calls"]["used"]),
                fmt_num(snap["capacity"]["total"]), fmt_num(snap["capacity"]["used"]),
                fmt_num(snap["traffic"]["total"]), fmt_num(snap["traffic"]["used"]),
                ((snap["calls"]["ratio"] + snap["capacity"]["ratio"] +
                  snap["traffic"]["ratio"]) / 3.0) * 100
                if snap["active_count"] else 0.0,
            ))
        self.emit(dt, "STAT ops=%d errors=%d active_pkgs=%d" % (
            self.calls_ops, self.errors, snap["active_count"]))

    def collect_events(self):
        events = []
        for p in self.pkgs:
            if p["order_time"]:
                events.append((p["order_time"], "ORDER", p))
            if p["pause"]:
                events.append((p["pause"], "PAUSE", p))
            if p["resume"]:
                events.append((p["resume"], "RESUME", p))
            if p["unsubscribe"]:
                events.append((p["unsubscribe"], "UNSUBSCRIBE", p))
        # 账期切换
        for c in self.cycles:
            if self.start <= c["start"] <= self.end:
                events.append((c["start"], "CYCLE_START", c))
        events.sort(key=lambda x: (x[0], x[1]))
        return events

    def emit_event(self, dt, kind, payload):
        if kind == "CYCLE_START":
            c = payload
            self.emit(dt, "USAGE_RESET cycle=%s reason=新计费周期开始 "
                       "calls_used=0 cap_used=0 traffic_used=0" % c["label"])
            self.emit_quota(dt, tag="RENEW")
            return
        p = payload
        if kind == "ORDER":
            self.emit(dt,
                "ORDER_EVENT kind=%s order_no=%s resource_id=%s amount=%s "
                "name=%s status=开通成功" % (
                    p["kind"], p["order_no"], p["resource_id"],
                    fmt_num(p["amount"]), p["name"]))
        elif kind == "PAUSE":
            self.emit(dt,
                "PAUSE_EVENT kind=%s order_no=%s resource_id=%s at=%s" % (
                    p["kind"], p["order_no"], p["resource_id"], ts(dt)))
        elif kind == "RESUME":
            self.emit(dt,
                "RESUME_EVENT kind=%s order_no=%s resource_id=%s at=%s" % (
                    p["kind"], p["order_no"], p["resource_id"], ts(dt)))
        elif kind == "UNSUBSCRIBE":
            self.emit(dt,
                "UNSUBSCRIBE_EVENT kind=%s order_no=%s resource_id=%s at=%s status=已退订" % (
                    p["kind"], p["order_no"], p["resource_id"], ts(dt)))

    def build(self):
        self.write_banner(self.start)
        events = [(t, k, p) for (t, k, p) in self.collect_events()
                  if self.start <= t <= self.end]
        ei = 0
        cur = self.start
        sample = timedelta(minutes=self.sample_minutes)
        last_cycle = None
        day_i = 0

        # 若起点早于首单，先说明
        if cur < self.anchor:
            self.emit(cur, "INFO waiting first order anchor=%s" % ts(self.anchor))

        while cur <= self.end:
            while ei < len(events) and events[ei][0] <= cur:
                t, k, p = events[ei]
                self.emit_event(t, k, p)
                ei += 1

            c = self.inv.cycle_for(cur)
            if c and last_cycle is None:
                last_cycle = c["index"]
            if c and last_cycle and c["index"] != last_cycle:
                last_cycle = c["index"]

            if cur >= self.anchor:
                self.emit_ops(cur)
                day_i += 1
                if day_i % 6 == 0:
                    self.emit_quota(cur, tag="RESOURCE")

            cur += sample

        # flush remaining events
        while ei < len(events):
            t, k, p = events[ei]
            self.emit_event(t, k, p)
            ei += 1

        final = self.emit_quota(self.end, tag="FINAL")
        self.emit(self.end, "========== EOS resource usage log v2 end ==========")
        self.emit(self.end,
            "FINAL_CHECK period=%s~%s active_pkgs=%d "
            "calls=%s/%s万次(%.1f%%) cap=%s/%sGB(%.1f%%) traffic=%s/%sGB(%.1f%%)" % (
                self.start.strftime("%Y%m%d"), self.end.strftime("%Y%m%d"),
                final["active_count"],
                fmt_num(final["calls"]["used"]), fmt_num(final["calls"]["total"]),
                final["calls"]["ratio"] * 100,
                fmt_num(final["capacity"]["used"]), fmt_num(final["capacity"]["total"]),
                final["capacity"]["ratio"] * 100,
                fmt_num(final["traffic"]["used"]), fmt_num(final["traffic"]["total"]),
                final["traffic"]["ratio"] * 100,
            ))
        return self.lines


def main():
    p = argparse.ArgumentParser(description="EOS 资源使用日志 v2（按 20260601-20260826 表）")
    p.add_argument("--data", default=DEFAULT_DATA, help="资源包 JSON 数据文件")
    p.add_argument("--start", default="20260601")
    p.add_argument("--end", default="20260826")
    p.add_argument("-o", "--output", default="-")
    p.add_argument("--sample-minutes", type=int, default=360)
    p.add_argument("--usage-start", type=float, default=0.0)
    p.add_argument("--usage-end", type=float, default=0.75)
    p.add_argument("--seed", default="eos-20260601-20260826")
    p.add_argument("--verbose-ratio", type=float, default=0.08)
    args = p.parse_args()

    pkgs = load_packages(args.data)
    start = parse_time(args.start)
    end = parse_time(args.end)
    if len(str(args.end).strip()) <= 10:
        end = end_of_day(end)

    builder = LogBuilder(
        pkgs=pkgs,
        start=start,
        end=end,
        sample_minutes=args.sample_minutes,
        usage_start=args.usage_start,
        usage_end=args.usage_end,
        seed=args.seed,
        verbose_ratio=args.verbose_ratio,
    )
    lines = builder.build()
    text = "\n".join(lines) + "\n"
    if args.output == "-":
        sys.stdout.write(text)
    else:
        with open(args.output, "w") as f:
            f.write(text)
        print("lines=%d packages=%d -> %s" % (len(lines), len(pkgs), args.output),
              file=sys.stderr)
        for ln in lines:
            if "FINAL_CHECK" in ln:
                print(ln, file=sys.stderr)


if __name__ == "__main__":
    main()
