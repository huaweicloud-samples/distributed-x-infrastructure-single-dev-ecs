# 单一 ECS 开发主机 · 华为云部署指导书

> 基于 Terraform + huaweicloud Provider 的一键部署与运维指引。

## 1. 前置条件

- 华为云账号，具备 VPC / ECS / EIP / 密钥对 /（可选）DNS 的创建权限。
- 本地安装：[Terraform](https://www.terraform.io/downloads) >= 1.5、Python >= 3.7（运维脚本用）。
- 配置凭据（仅环境变量，不落盘）：
```bash
export HW_ACCESS_KEY="<HW_ACCESS_KEY>"
export HW_SECRET_KEY="<HW_SECRET_KEY>"
# 临时凭证再加：
export HW_SECURITY_TOKEN="<TOKEN>"
```
- 准备 SSH 公钥（如 `~/.ssh/id_rsa.pub`）。

## 2. 快速开始

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# 编辑 terraform.tfvars：至少填写 public_key（建议用变量注入： -var="public_key=$(cat ~/.ssh/id_rsa.pub)"）
# 推荐把 public_key 通过命令行注入，避免写进文件：
terraform init
terraform plan -var="public_key=$(cat ~/.ssh/id_rsa.pub)"
terraform apply -var="public_key=$(cat ~/.ssh/id_rsa.pub)"
```

> 部署前请确认目标区域具备所需资源配额与权限。

部署完成后生成连接信息：

```bash
terraform output ssh_command
# ssh -i <私钥> root@<EIP>
```

## 3. 运维脚本（src/scripts）

首次使用请先生成 `outputs.json` 供脚本读取实例 ID / EIP：

```bash
terraform output -json > src/outputs.json
cp src/configs/config.json.example src/configs/config.json # 按需改 region / nick_name / key_file
pip install -r src/scripts/requirements.txt
```

| 命令 | 作用 |
|---|---|
| `python src/scripts/ecs status` | 查看 ECS 运行状态 |
| `python src/scripts/ecs start` | 启动（SHUTOFF→ACTIVE） |
| `python src/scripts/ecs stop` | 停机（ACTIVE→SHUTOFF） |
| `python src/scripts/setssh` | 把 EIP 写入 `~/.ssh/config` |

连接：`ssh <nick_name>`（由 setssh 写入配置）。

## 4. 可选：开机自动更新 DNS 记录

1. 在云解析创建公网 Zone（如 `example.com`），记录其 Zone ID。
2. `terraform.tfvars` 中设置：
```hcl
dns_zone_id = "<zone-id>"
dns_domain = "example.com"
account_domain = "<IAM 账号域名>" # 创建委托必填
```
3. `terraform apply`。ECS 创建后每次开机，会自动把本机 EIP 写入 `<ecs_name>.<dns_domain>` 的 A 记录。

## 5. 清理资源

```bash
terraform destroy
# 并 API 直查确认无残留（EIP / ECS / 安全组等），尤其销毁后留意是否有孤立云硬盘
```

> `destroy` 后须再经 API 直查确认无资源残留；被 `state rm` / 手动摘出的资源不在销毁范围内，需单独核查。
