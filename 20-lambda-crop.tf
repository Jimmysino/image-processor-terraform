data "archive_file" "crop" {
  type        = "zip"
  source_dir  = "src/crop"
  output_path = "build/crop.zip"
}

resource "aws_cloudwatch_log_group" "crop" {
  name              = "/aws/lambda/${local.name}-crop"
  retention_in_days = 14
}

resource "aws_lambda_function" "crop" {
  function_name    = "${local.name}-crop"
  role             = aws_iam_role.crop.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 60
  filename         = data.archive_file.crop.output_path
  source_code_hash = data.archive_file.crop.output_base64sha256

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.images.bucket
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.crop.id]
  }

  depends_on = [aws_cloudwatch_log_group.crop, aws_iam_role_policy_attachment.crop_vpc]
}

resource "aws_lambda_event_source_mapping" "crop" {
  event_source_arn        = aws_sqs_queue.main.arn
  function_name           = aws_lambda_function.crop.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
}