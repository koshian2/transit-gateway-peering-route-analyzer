terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# 2つのVPCを作成
module "vpc1" {
  source = "../vpc"

  vpc_name           = "${var.prefix}-vpc1"
  vpc_cidr_block     = var.vpc1_cidr_block
  availability_zones = var.availability_zones
}

module "vpc2" {
  source = "../vpc"

  vpc_name           = "${var.prefix}-vpc2"
  vpc_cidr_block     = var.vpc2_cidr_block
  availability_zones = var.availability_zones
}

# Transit Gatewayを作成
resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "${var.prefix}-transit-gateway"
  amazon_side_asn                 = var.transit_gateway_asn
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments  = "enable"

  tags = {
    Name = "${var.prefix}-tgw"
  }
}

# VPC1をTransit Gatewayにアタッチ
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc1_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.vpc1.vpc_id
  subnet_ids         = module.vpc1.private_subnet_ids

  tags = {
    Name = "${var.prefix}-vpc1-tgw-attachment"
  }
}

# VPC2をTransit Gatewayにアタッチ
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc2_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.vpc2.vpc_id
  subnet_ids         = module.vpc2.private_subnet_ids

  tags = {
    Name = "${var.prefix}-vpc2-tgw-attachment"
  }
}

# VPC1のプライベートルートテーブルにVPC2へのルートを追加
resource "aws_route" "vpc1_to_vpc2" {
  route_table_id         = module.vpc1.private_route_table_id
  destination_cidr_block = module.vpc2.vpc_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

# VPC2のプライベートルートテーブルにVPC1へのルートを追加
resource "aws_route" "vpc2_to_vpc1" {
  route_table_id         = module.vpc2.private_route_table_id
  destination_cidr_block = module.vpc1.vpc_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}