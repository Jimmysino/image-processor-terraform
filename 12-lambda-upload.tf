data "archive_file" "upload" {
  type        = "zip"
  source_dir  = "src/upload"
  output_path = "build/upload.zip"
}

resource "aws_cloudwatch_log_group" "upload" {
  name              = "/aws/lambda/${local.name}-upload"
  retention_in_days = 14
}

resource "aws_lambda_function" "upload" {
  function_name    = "${local.name}-upload"
  role             = aws_iam_role.upload.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 30
  filename         = data.archive_file.upload.output_path
  source_code_hash = data.archive_file.upload.output_base64sha256

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.images.bucket
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.upload.id]
  }

  depends_on = [aws_cloudwatch_log_group.upload, aws_iam_role_policy_attachment.upload_vpc]
}