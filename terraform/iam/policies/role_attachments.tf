resource "aws_iam_role_policy_attachment" "attach_access_to_ec2_role" {
  role       = var.ec2_role_name
  policy_arn = module.web_analytics.policy_arn
}
