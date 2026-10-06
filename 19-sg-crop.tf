resource "aws_security_group" "crop" {
  name        = "${local.name}-sg-crop-lambda"
  description = "crop-lambda sin entrada"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "crop_a_s3" {
  security_group_id = aws_security_group.crop.id
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "crop_a_sqs" {
  security_group_id            = aws_security_group.crop.id
  referenced_security_group_id = aws_security_group.vpce_sqs.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_ingress_rule" "sqs_desde_crop" {
  security_group_id            = aws_security_group.vpce_sqs.id
  referenced_security_group_id = aws_security_group.crop.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}