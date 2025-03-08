# セキュリティグループの作成
resource "aws_security_group" "instance_sg_jp" {
  provider = aws.jp
  for_each = {
    "jp-vpc1" = module.multi_vpc_region1.vpc1_id
    "jp-vpc2" = module.multi_vpc_region1.vpc2_id
  }

  name        = "${each.key}-sg"
  description = "Security group for ${each.key}"
  vpc_id      = each.value

  # HTTPアクセス許可
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/15"] # 適当にVPC全体の範囲をカバーできるCIDRにしておく
  }

  # ICMP (ping)許可
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.10.0.0/15"]
  }

  # 全ての送信トラフィックを許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${each.value}-sg"
  }
}

resource "aws_security_group" "instance_sg_us" {
  provider = aws.us
  for_each = {
    "us-vpc1" = module.multi_vpc_region2.vpc1_id
    "us-vpc2" = module.multi_vpc_region2.vpc2_id
  }

  name        = "${each.key}-sg"
  description = "Security group for ${each.key}"
  vpc_id      = each.value

  # HTTPアクセス許可
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/15"] # 適当にVPC全体の範囲をカバーできるCIDRにしておく
  }

  # ICMP (ping)許可
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.10.0.0/15"]
  }

  # 全ての送信トラフィックを許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${each.value}-sg"
  }
}

# Session Manager用のIAMロール
resource "aws_iam_role" "ssm_role" {
  provider = aws.jp
  name     = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })

  tags = {
    Name = "ec2-ssm-role"
  }
}

# SSM関連のポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  provider   = aws.jp
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAMインスタンスプロファイル
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  provider = aws.jp
  name     = "ssm-instance-profile"
  role     = aws_iam_role.ssm_role.name
}

# Amazon Linux 2023
data "aws_ami" "amazon_linux_jp" {
  provider    = aws.jp
  most_recent = true
  owners      = ["137112412989"] # AmazonのAMI所有者ID

  filter {
    name = "name"
    # Amazon Linux 2023 AMIの名前パターン。minimumを除外する
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "amazon_linux_us" {
  provider    = aws.us # AMI IDがリージョンレベルで異なるため
  most_recent = true
  owners      = ["137112412989"] # AmazonのAMI所有者ID

  filter {
    name = "name"
    # Amazon Linux 2023 AMIの名前パターン。minimumを除外する
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2インスタンス
resource "aws_instance" "web_server_jp" {
  provider = aws.jp
  for_each = {
    "jp-vpc1" = module.multi_vpc_region1.vpc1_private_subnet_ids
    "jp-vpc2" = module.multi_vpc_region1.vpc2_private_subnet_ids
  }

  ami                         = data.aws_ami.amazon_linux_jp.id
  instance_type               = "t3.micro"
  subnet_id                   = each.value[0]
  vpc_security_group_ids      = [aws_security_group.instance_sg_jp[each.key].id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y httpd
    systemctl start httpd
    systemctl enable httpd
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_IP=$(hostname -I | awk '{print $1}')
    AVAILABILITY_ZONE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

    # 表示するHTMLページの作成
    cat > /var/www/html/index.html <<HTMLDOC
    <!DOCTYPE html>
    <html>
    <head>
        <title>VPC Information</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
            h1 { color: #333; }
            .info { background-color: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px auto; max-width: 600px; }
        </style>
    </head>
    <body>
        <h1>EC2 Instance Information</h1>
        <div class="info">
            <h2>${each.key}</h2>
            <p>Subnet ID: ${each.value[0]}</p>
            <p>Instance Private IP: $${INSTANCE_IP}</p>
            <p>Availability Zone: $${AVAILABILITY_ZONE}</p>
            <p>Instance ID: $${INSTANCE_ID}</p>
        </div>
    </body>
    </html>
    HTMLDOC
  EOF

  tags = {
    Name = "transit-instance-${each.key}"
  }
}

resource "aws_instance" "web_server_us" {
  provider = aws.us
  for_each = {
    "us-vpc1" = module.multi_vpc_region2.vpc1_private_subnet_ids
    "us-vpc2" = module.multi_vpc_region2.vpc2_private_subnet_ids
  }

  ami                         = data.aws_ami.amazon_linux_us.id
  instance_type               = "t3.micro"
  subnet_id                   = each.value[0]
  vpc_security_group_ids      = [aws_security_group.instance_sg_us[each.key].id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y httpd
    systemctl start httpd
    systemctl enable httpd
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_IP=$(hostname -I | awk '{print $1}')
    AVAILABILITY_ZONE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

    # 表示するHTMLページの作成
    cat > /var/www/html/index.html <<HTMLDOC
    <!DOCTYPE html>
    <html>
    <head>
        <title>VPC Information</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
            h1 { color: #333; }
            .info { background-color: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px auto; max-width: 600px; }
        </style>
    </head>
    <body>
        <h1>EC2 Instance Information</h1>
        <div class="info">
            <h2>${each.key}</h2>
            <p>Subnet ID: ${each.value[0]}</p>
            <p>Instance Private IP: $${INSTANCE_IP}</p>
            <p>Availability Zone: $${AVAILABILITY_ZONE}</p>
            <p>Instance ID: $${INSTANCE_ID}</p>
        </div>
    </body>
    </html>
    HTMLDOC
  EOF

  tags = {
    Name = "transit-instance-${each.key}"
  }
}