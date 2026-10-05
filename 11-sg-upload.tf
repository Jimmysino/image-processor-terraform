resource "aws_security_group" "upload" {
  name        = "${local.name}-sg-upload-lambda"
  description = "upload-lambda sin entrada"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "upload_a_s3" {
  security_group_id = aws_security_group.upload.id
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}