# ============================================================================
# 输出
# ============================================================================

output "ecs_id" {
  description = "ECS 实例 ID（供 scripts/ecs、scripts/setssh 使用）"
  value       = huaweicloud_compute_instance.dev.id
}

output "eip_address" {
  description = "ECS 绑定的弹性公网 IP，用于 SSH 连接"
  value       = huaweicloud_vpc_eip.dev.address
}

output "ssh_command" {
  description = "连接 ECS 的示例命令"
  value       = "ssh -i <your-private-key> root@${huaweicloud_vpc_eip.dev.address}"
}

output "dns_agency_name" {
  description = "DNS 委托名称（仅启用 DNS 时有值）"
  value       = var.dns_zone_id != "" ? huaweicloud_identity_agency.ecs_dns[0].name : ""
}
