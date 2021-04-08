resource "aws_lambda_function" "asa-audit-logs" {
  filename         = "${path.module}/files/lambda/asa-audit-logs.zip"
  function_name    = "${var.env}-asa-audit-logs"
  role             = aws_iam_role.asa-audit-logs.arn
  handler          = "audit_logs.lambda_handler"
  source_code_hash = "${filebase64sha256("${path.module}/files/lambda/asa-audit-logs.zip")}"
  runtime          = "ruby2.7"
  timeout          = "600"

  environment {
    variables = {
      ENVIRONMENT        = var.env
      ASA_API_KEY_PATH = var.asa_api_key_path
      ASA_API_SECRET_PATH = var.asa_api_secret_path
      ASA_TEAM = var.asa_team
      TIME_INTERVAL = var.time_internval
    }
  }
}

locals{
  schedule_expression = "rate(${var.time_internval} minutes)"  
}

resource "aws_cloudwatch_event_rule" "asa_audit_logs_scheduled_execution" {
  name        = "${var.env}-asa-audit-logs_scheduled-execution"
  description = "Run audit-logs lambda on a schedule"
  schedule_expression = local.schedule_expression
}

resource "aws_cloudwatch_event_target" "asa-audit-logs" {
  rule = aws_cloudwatch_event_rule.asa_audit_logs_scheduled_execution.name
  arn  = aws_lambda_function.asa-audit-logs.arn
}

resource "aws_lambda_permission" "events" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asa-audit-logs.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asa_audit_logs_scheduled_execution.arn
}

resource "aws_iam_role" "asa-audit-logs" {
  name = "${var.env}-asa-audit-logs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

}

resource "aws_iam_policy" "asa-audit-logs" {
  name        = "${var.env}-asa-audit-logs"
  description = "Allow asa-audit-logs lambda to write CloudWatch logs and read SSM secrets."
  policy      = data.aws_iam_policy_document.asa-audit-logs.json
}

data "aws_iam_policy_document" "asa-audit-logs" {
  statement {
    sid       = "CreateLogGroup"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid     = "CreatePutLogEvents"
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "arn:aws:logs:**:*:log-group:/aws/lambda/${var.env}-asa-audit-logs:*",
    ]
  }

  statement {
    sid       = "DescribeAllParameters"
    effect    = "Allow"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }

  statement {
    sid     = "GetApiParams"
    effect  = "Allow"
    actions = ["ssm:GetParameter*"]
    resources = [
      "arn:aws:ssm:*:*:parameter${var.asa_api_key_path}",
      "arn:aws:ssm:*:*:parameter${var.asa_api_secret_path}",
    ]
  }

  statement {
    sid       = "DecryptParams"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["${var.kms_key_arn}"]
  }
}

resource "aws_iam_role_policy_attachment" "attach-asa-audit-logs" {
  role       = aws_iam_role.asa-audit-logs.name
  policy_arn = aws_iam_policy.asa-audit-logs.arn
}
