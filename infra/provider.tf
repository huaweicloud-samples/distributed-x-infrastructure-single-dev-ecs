terraform {
  required_version = ">= 1.5"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }

  # 调试/学习建议用本地 state；多人对齐或生产请改用 OBS 后端（取消注释即可）。
  backend "local" {
    # 生产环境改为：
    # backend "s3" {
    #   endpoint   = "https://obs.<region>.myhuaweicloud.com"
    #   bucket     = "<your-tfstate-bucket>"
    #   key        = "distributed-x-infrastructure-single-dev-ecs/terraform.tfstate"
    #   region     = "<region>"
    # }
  }
}

provider "huaweicloud" {
  region = var.region
  # AK/SK 从环境变量读取，绝不硬编码：
  #   export HW_ACCESS_KEY="<HW_ACCESS_KEY>"
  #   export HW_SECRET_KEY="<HW_SECRET_KEY>"
  # 临时凭证再加：
  #   export HW_SECURITY_TOKEN="<TOKEN>"
}
