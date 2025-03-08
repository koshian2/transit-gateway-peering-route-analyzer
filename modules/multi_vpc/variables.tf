variable "prefix" {
  type        = string
  description = "リソースの名前のプレフィックス"
}

variable "vpc1_cidr_block" {
  type        = string
  description = "VPC1のCIDRブロック"
}

variable "vpc2_cidr_block" {
  type        = string
  description = "VPC2のCIDRブロック"
}

variable "availability_zones" {
  type        = list(string)
  description = "利用可能なアベイラビリティーゾーンのリスト"
}

variable "transit_gateway_asn" {
  type        = number
  description = "Transit GatewayのASN番号"
  default     = 64512
}