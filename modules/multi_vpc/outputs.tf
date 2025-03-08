output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.tgw.id
}

output "vpc1_id" {
  value = module.vpc1.vpc_id
}

output "vpc2_id" {
  value = module.vpc2.vpc_id
}

output "vpc1_cidr_block" {
  value = module.vpc1.vpc_cidr_block
}

output "vpc2_cidr_block" {
  value = module.vpc2.vpc_cidr_block
}

output "vpc1_public_subnet_ids" {
  value = module.vpc1.public_subnet_ids
}

output "vpc1_private_subnet_ids" {
  value = module.vpc1.private_subnet_ids
}

output "vpc2_public_subnet_ids" {
  value = module.vpc2.public_subnet_ids
}

output "vpc2_private_subnet_ids" {
  value = module.vpc2.private_subnet_ids
}

output "vpc1_private_route_table_id" {
  value = module.vpc1.private_route_table_id
}

output "vpc2_private_route_table_id" {
  value = module.vpc2.private_route_table_id
}

output "transit_gateway_route_table_id" {
  value = aws_ec2_transit_gateway.tgw.association_default_route_table_id
}

output "transit_gateway_arn" {
  value = aws_ec2_transit_gateway.tgw.arn
}