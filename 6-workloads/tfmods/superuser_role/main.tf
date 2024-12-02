resource "aws_iam_role" "superuser_role" {
  name = "superuser"

  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          AWS : "arn:aws:iam::647355953950:role/pod-role" # Central account pod role
        },
        Action : [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "superuser_policy" {
  name        = "superuser-policy"
  description = "Superuser policy for cross-account access"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : "*",
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "superuser_policy_attachment" {
  role       = aws_iam_role.superuser_role.name
  policy_arn = aws_iam_policy.superuser_policy.arn
}

output "superuser_role_arn" {
  value = aws_iam_role.superuser_role.arn
}
