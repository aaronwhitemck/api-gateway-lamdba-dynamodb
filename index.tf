data "archive_file" "lambda_yourapp_index" {
  type = "zip"
  source_dir  = "${path.module}/client"
  output_path = "${path.module}/zip/index.zip"
}

resource "aws_s3_object" "lambda_yourapp_index" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "index.zip"
  source = data.archive_file.lambda_yourapp_index.output_path
  etag = filemd5(data.archive_file.lambda_yourapp_index.output_path)
}

resource "aws_lambda_function" "index_yourapp_func" {
  function_name = "Index_yourapp"
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_yourapp_index.key
  runtime = "nodejs12.x"
  handler = "index.handler"
  source_code_hash = data.archive_file.lambda_yourapp_index.output_base64sha256
  role = aws_iam_role.index_lambda_yourapp_exec.arn
}

resource "aws_iam_role" "index_lambda_yourapp_exec" {
  name = "Index_lambda_yourapp_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_policy" "index_yourapp_lambda_policy" {
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CWLogs",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

resource "aws_lambda_permission" "index_yourapp_perm" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.index_yourapp_func.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_iam_role_policy_attachment" "index_yourapp_lambda_policy" {
  policy_arn = aws_iam_policy.index_yourapp_lambda_policy.arn
  role       = aws_iam_role.index_lambda_yourapp_exec.name
}

resource "aws_apigatewayv2_route" "index_yourapp_rte" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.index_yourapp_int.id}"
}

resource "aws_apigatewayv2_integration" "index_yourapp_int" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_uri    = aws_lambda_function.index_yourapp_func.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_cloudwatch_log_group" "index_cw" {
  name              = "/aws/lambda/${aws_lambda_function.index_yourapp_func.function_name}"
  retention_in_days = var.log_retention_days
}
