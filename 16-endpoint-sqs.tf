resource "aws_security_group" "vpce_sqs" {
  name        = "${local.name}-sg-vpce-sqs"
  description = "Endpoint SQS"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sqs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpce_sqs.id]

  tags = {
    Name = "${local.name}-vpce-sqs"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sqs_desde_upload" {
  security_group_id            = aws_security_group.vpce_sqs.id
  referenced_security_group_id = aws_security_group.upload.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "upload_a_sqs" {
  security_group_id            = aws_security_group.upload.id
  referenced_security_group_id = aws_security_group.vpce_sqs.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}