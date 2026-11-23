#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
开机把本机 EIP 写入云解析公网 A 记录。

设计要点：
- 凭证来自 ECS Agency：从元数据服务获取临时 AK/SK/Token，绝不落盘真实凭据。
- 配置来自 /etc/setdns.env（由用户数据在渲染期写入字面值）。
- 幂等：已有同名 A 记录则更新，否则创建。

依赖：huaweicloudsdkcore、huaweicloudsdkdns
"""
import os
import json
import urllib.request

from huaweicloudsdkcore.auth.credentials import BasicCredentials
from huaweicloudsdkdns.v2 import (
    DnsClient,
    ListRecordSetsRequest,
    CreateRecordSetRequest,
    CreateRecordSetReq,
    UpdateRecordSetRequest,
    UpdateRecordSetReq,
)
from huaweicloudsdkdns.v2.region.dns_region import DnsRegion

META = "http://169.254.169.254/latest/meta-data"


def read_env_file(path):
    cfg = {}
    try:
        with open(path) as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, val = line.split("=", 1)
                cfg[key.strip()] = val.strip()
    except Exception:
        pass
    return cfg


def http_get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "set-dns"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        return resp.read().decode().strip()


def main():
    cfg = read_env_file("/etc/setdns.env")
    zone_id = cfg.get("SETDNS_ZONE_ID")
    region = cfg.get("SETDNS_REGION")
    node = cfg.get("SETDNS_NODE")
    domain = cfg.get("SETDNS_DOMAIN")
    if not (zone_id and region and node and domain):
        print("set-dns: missing config in /etc/setdns.env, skip")
        return

    fqdn = "%s.%s." % (node, domain)

    try:
        my_ip = http_get(META + "/public-ipv4/")
    except Exception as exc:
        print("set-dns: cannot read public ip: %s" % exc)
        return
    if not my_ip:
        print("set-dns: empty public ip, skip")
        return

    # 从元数据服务获取 Agency 临时凭证（对应弹性云服务器 实例角色）
    try:
        token_json = json.loads(http_get(META + "/securitytoken"))
    except Exception as exc:
        print("set-dns: cannot read securitytoken: %s" % exc)
        return
    ak = token_json.get("access")
    sk = token_json.get("secret")
    st = token_json.get("securitytoken")
    if not (ak and sk and st):
        print("set-dns: incomplete securitytoken, skip")
        return

    creds = BasicCredentials(ak, sk).with_security_token(st)
    client = (
        DnsClient.new_builder()
        .with_credentials(creds)
        .with_region(DnsRegion.value_of(region))
        .build()
    )

    # 查找已有同名 A 记录
    existing = None
    try:
        resp = client.list_record_sets(ListRecordSetsRequest(zone_id=zone_id))
        for rs in getattr(resp, "recordsets", []) or []:
            if getattr(rs, "name", None) == fqdn and getattr(rs, "type", None) == "A":
                existing = rs
                break
    except Exception as exc:
        print("set-dns: list failed: %s" % exc)

    try:
        if existing:
            req = UpdateRecordSetRequest(
                zone_id=zone_id,
                recordset_id=existing.id,
                body=UpdateRecordSetReq(name=fqdn, type="A", ttl=300, records=[my_ip]),
            )
            client.update_record_set(req)
            print("set-dns: updated %s -> %s" % (fqdn, my_ip))
        else:
            req = CreateRecordSetRequest(
                zone_id=zone_id,
                body=CreateRecordSetReq(name=fqdn, type="A", ttl=300, records=[my_ip]),
            )
            client.create_record_set(req)
            print("set-dns: created %s -> %s" % (fqdn, my_ip))
    except Exception as exc:
        print("set-dns: upsert failed: %s" % exc)


if __name__ == "__main__":
    main()
