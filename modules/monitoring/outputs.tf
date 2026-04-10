output "cloudwatch_agent_role_arn" {
  value = aws_iam_role.cw_agent.arn
}

output "application_log_group" {
  value = aws_cloudwatch_log_group.application.name
}
