# ============================================================================
# 单一 ECS 开发主机 —— 华为云实践
# 资源：VPC + 子网 + 安全组 + 密钥对 + EIP + 单台 ECS（+ 可选 DNS 委托）
# ============================================================================

# ----------------------------------------------------------------------------
# 镜像：用 data 源按锚定正则取最新
# ----------------------------------------------------------------------------
data "huaweicloud_images_image" "dev" {
  name_regex  = "^${var.image_name}$" # 锚定首尾，避免命中 GPU 变体（见 docs/13 §4）
  most_recent = true
}

# ----------------------------------------------------------------------------
# 网络：VPC / 子网（华为云默认每 VPC 仅 1 张路由表，不新建，见 docs/13 §1）
# ----------------------------------------------------------------------------
resource "huaweicloud_vpc" "main" {
  name = "${var.name_prefix}-vpc"
  cidr = "10.0.0.0/16"
}

resource "huaweicloud_vpc_subnet" "main" {
  name       = "${var.name_prefix}-subnet"
  vpc_id     = huaweicloud_vpc.main.id
  cidr       = "10.0.1.0/24"
  gateway_ip = "10.0.1.1"
  dns_list   = ["100.125.1.250", "100.125.129.250"]
}

# ----------------------------------------------------------------------------
# 安全组：仅建入站 SSH 规则；出方向华为云默认自带 allow-all egress，勿重复建（docs/13 §3）
# ----------------------------------------------------------------------------
resource "huaweicloud_networking_secgroup" "main" {
  name        = "${var.name_prefix}-sg"
  description = "Single ECS dev host security group"
}

resource "huaweicloud_networking_secgroup_rule" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp" # 仅枚举 tcp/udp/icmp，不支持 all/-1（docs/13 §6）
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.ssh_allowed_cidr
  security_group_id = huaweicloud_networking_secgroup.main.id
}

# ----------------------------------------------------------------------------
# 密钥对：用提供的 SSH 公钥创建
# 若要用已有密钥对，删除本资源并给 huaweicloud_compute_instance 加 key_pair = "<已有名称>"
# ----------------------------------------------------------------------------
resource "huaweicloud_compute_keypair" "dev" {
  name       = "${var.name_prefix}-kp"
  public_key = var.public_key
}

# ----------------------------------------------------------------------------
# 弹性公网 IP（EIP）：绑定到 ECS 提供入站 SSH + 出站联网（含 yum 安装）
# ----------------------------------------------------------------------------
resource "huaweicloud_vpc_eip" "dev" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "${var.name_prefix}-eip-bw"
    size        = var.eip_bandwidth_size
    share_type  = "PER"
    charge_mode = var.eip_charge_mode
  }
}

# ----------------------------------------------------------------------------
# 可选：IAM 委托（Agency，弹性云服务器 ECS 类型）—— 让 ECS 以临时凭证调用云解析 API
# 仅在启用 DNS 时创建
# ----------------------------------------------------------------------------
resource "huaweicloud_identity_agency" "ecs_dns" {
  count                 = var.dns_zone_id != "" ? 1 : 0
  name                  = "${var.name_prefix}-ecs-dns-agency"
  description           = "Allow ECS to update a DNS A record on boot via Huawei Cloud DNS"
  duration              = "FOREVER"
  delegated_domain_name = var.account_domain

  project_role {
    project = var.region
    roles   = ["DNS FullAccess"]
  }
}

# ----------------------------------------------------------------------------
# 用户数据（cloud-init）：基础开发工具 + 可选开机 DNS 更新
# ----------------------------------------------------------------------------
locals {
  # 单一模板：注入 hostname 等变量，并在启用 DNS 时内嵌开机更新脚本
  user_data = templatefile("${path.module}/../src/userdata/user_script.sh.tpl", {
    ecs_name   = var.ecs_name
    nick_name  = var.nick_name
    dns_domain = var.dns_domain
    zone_id    = var.dns_zone_id
    region     = var.region
    set_dns_py = file("${path.module}/../src/scripts/set-dns.py")
  })
}

# ----------------------------------------------------------------------------
# 核心：单台 ECS 开发主机
# ----------------------------------------------------------------------------
resource "huaweicloud_compute_instance" "dev" {
  name               = "${var.name_prefix}-${var.ecs_name}"
  flavor_id          = var.flavor
  image_id           = data.huaweicloud_images_image.dev.id
  security_group_ids = [huaweicloud_networking_secgroup.main.id]
  availability_zone  = "${var.region}a"
  key_pair           = huaweicloud_compute_keypair.dev.name

  # DNS 开启时绑定 Agency，使实例可从元数据服务获取临时凭证（对应实例角色）
  agency_name = var.dns_zone_id != "" ? huaweicloud_identity_agency.ecs_dns[0].name : null

  network {
    uuid = huaweicloud_vpc_subnet.main.id # 子网层用 .id（docs/13 §2）
  }

  system_disk_type = var.system_disk_type
  system_disk_size = var.system_disk_size

  user_data = local.user_data

  # 运行期无字段被脚本改写，无需 ignore_changes
  tags = {
    ecs_name  = var.ecs_name
    nick_name = var.nick_name
    project   = var.name_prefix
  }
}

# ----------------------------------------------------------------------------
# EIP 关联：将公网 IP 绑到 ECS（对应自动分配 public IP）
# ----------------------------------------------------------------------------
resource "huaweicloud_compute_eip_associate" "dev" {
  instance_id = huaweicloud_compute_instance.dev.id
  public_ip   = huaweicloud_vpc_eip.dev.address
}
