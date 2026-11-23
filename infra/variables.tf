# ============================================================================
# 变量定义（主要规格与容量参数均显式设定，便于部署前确认配置）
# ============================================================================

variable "region" {
  description = "华为云区域，例如 cn-north-4（北京四）"
  type        = string
  default     = "cn-north-4"
}

variable "name_prefix" {
  description = "资源命名前缀，全局唯一，建议带项目/环境标识"
  type        = string
  default     = "single-ecs-dev"
}

variable "ecs_name" {
  description = "ECS 主机名（hostname），同时作为实例名称"
  type        = string
  default     = "dev"
}

variable "nick_name" {
  description = "SSH config 中使用的别名，ssh 时直接用此名连接"
  type        = string
  default     = "dev"
}

# --- 计算规格 ---
variable "flavor" {
  description = "ECS 规格，例如 s6.large.2（2vCPU 4GB）。可在任意 region 可用的通用计算型 s6 规格间调整"
  type        = string
  default     = "s6.large.2"
}

variable "image_name" {
  description = "公共镜像名称；用 data 源按锚定正则取最新"
  type        = string
  default     = "CentOS 7.9 64bit"
}

variable "system_disk_type" {
  description = "系统盘类型（华为云侧必填参数，常见 GPSSD/SSD）"
  type        = string
  default     = "GPSSD"
}

variable "system_disk_size" {
  description = "系统盘容量（GB），默认 100GB"
  type        = number
  default     = 100
}

# --- 登录 ---
variable "public_key" {
  description = "SSH 公钥内容（id_rsa.pub 全文），用于创建密钥对。也可改用已有密钥对（见 main.tf 注释）"
  type        = string
  sensitive   = true
}

variable "ssh_allowed_cidr" {
  description = "允许 SSH(22) 入站的源 CIDR。默认 0.0.0.0/0，强烈建议收敛到运维机 IP（如 1.2.3.4/32）"
  type        = string
  default     = "0.0.0.0/0"
}

# --- 公网出口（EIP）---
variable "eip_bandwidth_size" {
  description = "EIP 带宽上限（Mbps），在 traffic 模式下作为峰值限速"
  type        = number
  default     = 5
}

variable "eip_charge_mode" {
  description = "EIP 带宽模式：traffic（按流量）或 bandwidth（按固定带宽）"
  type        = string
  default     = "traffic"
}

# --- 可选：开机自动更新 DNS 记录 ---
variable "dns_zone_id" {
  description = "云解析公网 Zone ID。留空则关闭 DNS 自动更新能力（默认）"
  type        = string
  default     = ""
}

variable "dns_domain" {
  description = "云解析域名（不含末尾点），例如 example.com"
  type        = string
  default     = ""
}

variable "account_domain" {
  description = "IAM 所属域名（账号域名，创建 Agency 委托时必填）。仅当启用 DNS 时必填"
  type        = string
  default     = ""
}
