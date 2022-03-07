
data "archive_file" "lambda-zip" {
  type        = "zip"
  source_dir  = "lambda"
  output_path = "lambda.zip"

}

# Sending logs to CloudWatch
resource "aws_iam_role_policy" "cloudwatch" {
  name   = "cloudwatch"
  role   = aws_iam_role.lambda-iam-role.id
  policy = file("iam/lambda-cloudwatch-policy.json")

}

# SSM policy for get/put operations
resource "aws_iam_role_policy" "ssm" {
  name   = "ssm"
  role   = aws_iam_role.lambda-iam-role.id
  policy = file("iam/lambda-ssm-policy.json")

}

# Creating lambda assume role
resource "aws_iam_role" "lambda-iam-role" {
  name               = "lambda-iam-role-mk"
  assume_role_policy = file("iam/lambda-assume-policy.json")
}

# Creating lambda function
resource "aws_lambda_function" "lambda" {
  filename         = "lambda.zip"
  function_name    = "lambda-function"
  role             = aws_iam_role.lambda-iam-role.arn
  handler          = "lambda.lambda_handler"
  source_code_hash = data.archive_file.lambda-zip.output_base64sha256
  runtime          = "python3.8"

  tags = {
    CreatedBy = "Manish"
  }
}

# Creating HTTP API
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "lambda-iac-api"
  protocol_type = "HTTP"
  tags = {
    CreatedBy = "Manish"
  }

}

# Setting API Stage 
resource "aws_apigatewayv2_stage" "lambda-stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true
}


resource "aws_apigatewayv2_integration" "lambda-integration" {
  api_id               = aws_apigatewayv2_api.lambda_api.id
  integration_type     = "AWS_PROXY"
  integration_method   = var.integration_method
  integration_uri      = aws_lambda_function.lambda.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
}

# Setting API route 
resource "aws_apigatewayv2_route" "lambda_route" {
  api_id             = aws_apigatewayv2_api.lambda_api.id
  route_key          = var.route_key
  target             = "integrations/${aws_apigatewayv2_integration.lambda-integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}


resource "aws_lambda_permission" "api-gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*/*"
}

# Setting up jwt for API
resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "jwt-api-aws"

  jwt_configuration {
    audience = ["https://auth0-jwt-authorizer"]
    issuer   = "https://dev-z0xv08kg.us.auth0.com/"
  }
}
