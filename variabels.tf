variable "prefix" {
  type        = string
  description = "すべてのリソースのプレフィックス"
  default     = "multi-region-network"
}

variable "region1" {
  type        = string
  description = "第1リージョン"
  default     = "ap-northeast-1"
}

variable "region2" {
  type        = string
  description = "第2リージョン"
  default     = "us-east-1"
}

variable "region1_vpc1_cidr" {
  type        = string
  description = "リージョン1のVPC1のCIDRブロック"
  default     = "10.10.0.0/20"
}

variable "region1_vpc2_cidr" {
  type        = string
  description = "リージョン1のVPC2のCIDRブロック"
  default     = "10.10.16.0/20"
}

variable "region2_vpc1_cidr" {
  type        = string
  description = "リージョン2のVPC1のCIDRブロック"
  default     = "10.11.0.0/20"
}

variable "region2_vpc2_cidr" {
  type        = string
  description = "リージョン2のVPC2のCIDRブロック"
  default     = "10.11.16.0/20"
}

variable "region1_azs" {
  type        = list(string)
  description = "リージョン1のアベイラビリティーゾーン"
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "region2_azs" {
  type        = list(string)
  description = "リージョン2のアベイラビリティーゾーン"
  default     = ["us-east-1a", "us-east-1c", "us-east-1d"]
}

variable "region1_tgw_asn" {
  type        = number
  description = "リージョン1のTransit Gateway ASN"
  default     = 64512
}

variable "region2_tgw_asn" {
  type        = number
  description = "リージョン2のTransit Gateway ASN"
  default     = 64513
}