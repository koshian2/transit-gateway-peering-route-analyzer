
# 現在のAWSアカウントIDの取得
data "aws_caller_identity" "current" {
  provider = aws.jp
}

# リージョン1にTGW+VPCsを展開
module "multi_vpc_region1" {
  source = "./modules/multi_vpc"

  providers = {
    aws = aws.jp
  }

  prefix              = "${var.prefix}-jp"
  vpc1_cidr_block     = var.region1_vpc1_cidr
  vpc2_cidr_block     = var.region1_vpc2_cidr
  availability_zones  = var.region1_azs
  transit_gateway_asn = var.region1_tgw_asn
}

# リージョン2にTGW+VPCsを展開
module "multi_vpc_region2" {
  source = "./modules/multi_vpc"

  providers = {
    aws = aws.us
  }

  prefix              = "${var.prefix}-us"
  vpc1_cidr_block     = var.region2_vpc1_cidr
  vpc2_cidr_block     = var.region2_vpc2_cidr
  availability_zones  = var.region2_azs
  transit_gateway_asn = var.region2_tgw_asn
}

# Transit Gateway Peeringリクエスト (リージョン1→リージョン2)
resource "aws_ec2_transit_gateway_peering_attachment" "tgw_peering" {
  provider                = aws.jp
  peer_account_id         = data.aws_caller_identity.current.account_id
  peer_region             = var.region2
  peer_transit_gateway_id = module.multi_vpc_region2.transit_gateway_id
  transit_gateway_id      = module.multi_vpc_region1.transit_gateway_id

  tags = {
    Name = "${var.prefix}-tgw-peering"
  }
}

# Transit Gateway Peering承認 (リージョン2側)
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "tgw_peering_accepter" {
  provider                      = aws.us
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.tgw_peering.id


  tags = {
    Name = "${var.prefix}-tgw-peering-accepter"
  }
}

# リージョン1のTGWからリージョン2のVPCへのルート設定
resource "aws_ec2_transit_gateway_route" "region1_to_region2_vpc1" {
  provider                       = aws.jp
  destination_cidr_block         = module.multi_vpc_region2.vpc1_cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tgw_peering.id
  transit_gateway_route_table_id = module.multi_vpc_region1.transit_gateway_route_table_id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

resource "aws_ec2_transit_gateway_route" "region1_to_region2_vpc2" {
  provider                       = aws.jp
  destination_cidr_block         = module.multi_vpc_region2.vpc2_cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tgw_peering.id
  transit_gateway_route_table_id = module.multi_vpc_region1.transit_gateway_route_table_id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

# リージョン2のTGWからリージョン1のVPCへのルート設定
resource "aws_ec2_transit_gateway_route" "region2_to_region1_vpc1" {
  provider                       = aws.us
  destination_cidr_block         = module.multi_vpc_region1.vpc1_cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tgw_peering.id
  transit_gateway_route_table_id = module.multi_vpc_region2.transit_gateway_route_table_id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

resource "aws_ec2_transit_gateway_route" "region2_to_region1_vpc2" {
  provider                       = aws.us
  destination_cidr_block         = module.multi_vpc_region1.vpc2_cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tgw_peering.id
  transit_gateway_route_table_id = module.multi_vpc_region2.transit_gateway_route_table_id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}


# モジュール側ではリージョン内の通信のみルートテーブルに追加しているので、リージョン間の通信もルートテーブルに追加する
# メッシュを張っているので冗長になるが、一定ブラックホールが出ていいならまとめたサブネットを1個追加するでもOK
# リージョン1の VPC1 に、リージョン2の VPC1 へのルートを追加
resource "aws_route" "region1_vpc1_to_region2_vpc1" {
  provider               = aws.jp
  route_table_id         = module.multi_vpc_region1.vpc1_private_route_table_id
  destination_cidr_block = module.multi_vpc_region2.vpc1_cidr_block
  transit_gateway_id     = module.multi_vpc_region1.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

# リージョン1の VPC1 に、リージョン2の VPC2 へのルートを追加
resource "aws_route" "region1_vpc1_to_region2_vpc2" {
  provider               = aws.jp
  route_table_id         = module.multi_vpc_region1.vpc1_private_route_table_id
  destination_cidr_block = module.multi_vpc_region2.vpc2_cidr_block
  transit_gateway_id     = module.multi_vpc_region1.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

# 同様に、リージョン1の VPC2 に対してもルートを追加
resource "aws_route" "region1_vpc2_to_region2_vpc1" {
  provider               = aws.jp
  route_table_id         = module.multi_vpc_region1.vpc2_private_route_table_id
  destination_cidr_block = module.multi_vpc_region2.vpc1_cidr_block
  transit_gateway_id     = module.multi_vpc_region1.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

resource "aws_route" "region1_vpc2_to_region2_vpc2" {
  provider               = aws.jp
  route_table_id         = module.multi_vpc_region1.vpc2_private_route_table_id
  destination_cidr_block = module.multi_vpc_region2.vpc2_cidr_block
  transit_gateway_id     = module.multi_vpc_region1.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

# リージョン2側も同様に、リージョン1のCIDRへのルートを追加
resource "aws_route" "region2_vpc1_to_region1_vpc1" {
  provider               = aws.us
  route_table_id         = module.multi_vpc_region2.vpc1_private_route_table_id
  destination_cidr_block = module.multi_vpc_region1.vpc1_cidr_block
  transit_gateway_id     = module.multi_vpc_region2.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

resource "aws_route" "region2_vpc1_to_region1_vpc2" {
  provider               = aws.us
  route_table_id         = module.multi_vpc_region2.vpc1_private_route_table_id
  destination_cidr_block = module.multi_vpc_region1.vpc2_cidr_block
  transit_gateway_id     = module.multi_vpc_region2.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

resource "aws_route" "region2_vpc2_to_region1_vpc1" {
  provider               = aws.us
  route_table_id         = module.multi_vpc_region2.vpc2_private_route_table_id
  destination_cidr_block = module.multi_vpc_region1.vpc1_cidr_block
  transit_gateway_id     = module.multi_vpc_region2.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

resource "aws_route" "region2_vpc2_to_region1_vpc2" {
  provider               = aws.us
  route_table_id         = module.multi_vpc_region2.vpc2_private_route_table_id
  destination_cidr_block = module.multi_vpc_region1.vpc2_cidr_block
  transit_gateway_id     = module.multi_vpc_region2.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tgw_peering_accepter]
}

# モニタリング用のグローバルネットワーク
resource "aws_networkmanager_global_network" "global_network" {
  provider    = aws.jp
  description = "Global network for TGW analysis"
}

# Transit Gatewayの登録
resource "aws_networkmanager_transit_gateway_registration" "tgw_jp" {
  provider            = aws.jp
  global_network_id   = aws_networkmanager_global_network.global_network.id
  transit_gateway_arn = module.multi_vpc_region1.transit_gateway_arn
}

resource "aws_networkmanager_transit_gateway_registration" "tgw_us" {
  provider            = aws.us
  global_network_id   = aws_networkmanager_global_network.global_network.id
  transit_gateway_arn = module.multi_vpc_region2.transit_gateway_arn
}
