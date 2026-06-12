# Expose the secret ARN as an output so it can be referenced in the GitHub Actions workflow.
output "db_secret_arn" {
  value       = aws_secretsmanager_secret.db.arn
  description = "ARN of the Secrets Manager secret containing the PostgreSQL credentials."
}