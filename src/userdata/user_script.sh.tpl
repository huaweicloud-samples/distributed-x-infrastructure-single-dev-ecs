#! /bin/bash -x
# ============================================================================
# 单一 ECS 开发主机 用户数据（cloud-init）
# 安装基础开发工具并配置主机名；启用 DNS 时追加「开机自动更新 A 记录」能力。
# 说明：本文件由 Terraform templatefile 渲染，$${...} 为注入变量，其余 $VAR 为 shell 变量。
# ============================================================================

# --- 基础工具 ---
sudo yum -y update
sudo yum -y install git jq curl wget expect python3 python3-pip

# --- 华为云 Python SDK ---
sudo pip3 install --upgrade pip
sudo pip3 install huaweicloudsdkcore huaweicloudsdkecs huaweicloudsdkdns

# --- Node 工具链 ---
# 注意：华为云 ECS 默认出口不可达 GitHub，故不从 GitHub 拉 nvm，
# 直接装官方二进制（nodejs.org 在 cn-north-4 可达；registry.npmmirror.com 亦可作备用）。
NODE_VER=16.20.2
curl -fSL -o /tmp/node.tar.xz https://nodejs.org/dist/v$${NODE_VER}/node-v$${NODE_VER}-linux-x64.tar.xz
tar -xf /tmp/node.tar.xz -C /usr/local --strip-components=1
rm -f /tmp/node.tar.xz
node -v && npm -v
npm install -g yarn typescript || echo "yarn/typescript install skipped (npm registry unreachable)"

# --- 主机名（注入变量：ecs_name / dns_domain）---
echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
%{ if dns_domain != "" }
hostnamectl set-hostname ${ecs_name}.${dns_domain}
%{ else }
hostnamectl set-hostname ${ecs_name}
%{ endif }

# ============================================================================
# 可选：开机自动把本机 EIP 写入云解析 A 记录
# 仅当部署时填了 dns_zone_id 才生成此段
# ============================================================================
%{ if zone_id != "" }
# 写入 DNS 配置（部署变量在渲染期注入为字面值）
cat > /etc/setdns.env << EOF
SETDNS_ZONE_ID=${zone_id}
SETDNS_REGION=${region}
SETDNS_NODE=${ecs_name}
SETDNS_DOMAIN=${dns_domain}
EOF

cat << 'PYEOF' > /var/lib/cloud/scripts/per-boot/set-dns
${set_dns_py}
PYEOF
chmod +x /var/lib/cloud/scripts/per-boot/set-dns

# 立即执行一次（不等奖本周期）
python3 /var/lib/cloud/scripts/per-boot/set-dns
%{ endif }

# 排障：tail -f /var/log/cloud-init-output.log
