# Lambda do diagrama: roda dentro da VPC (sub-redes privadas), enxerga o RDS,
# o S3 (pelo gateway endpoint) e as redes on-prem pelo Transit Gateway.

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/saida/lambda.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.projeto}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "lambda_s3" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.dados.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.dados.arn}/*"]
  }
}

resource "aws_iam_role_policy" "lambda_s3" {
  name   = "s3-dados"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_s3.json
}

resource "aws_security_group" "lambda" {
  name        = "${var.projeto}-lambda"
  description = "Lambda - so saida"
  vpc_id      = aws_vpc.principal.id

  egress {
    description = "Saida para VPC, S3 e on-prem"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.projeto}-sg-lambda" }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.projeto}-funcao"
  retention_in_days = 14
}

resource "aws_lambda_function" "principal" {
  function_name    = "${var.projeto}-funcao"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 15
  memory_size      = 128

  vpc_config {
    subnet_ids         = aws_subnet.privada[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      BUCKET  = aws_s3_bucket.dados.bucket
      DB_HOST = aws_db_instance.principal.address
      DB_PORT = tostring(aws_db_instance.principal.port)
      DB_NAME = aws_db_instance.principal.db_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_vpc,
  ]
}
