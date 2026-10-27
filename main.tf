# Task 1: Multi-Instance EC2 Provisioning
resource "aws_instance" "cluster" {
  for_each = var.instances

  ami           = each.value.ami
  instance_type = each.value.instance_type
  key_name      = each.value.key_name

  root_block_device {
    volume_type = each.value.volume_type
    volume_size = each.value.volume_size
  }

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  }

  lifecycle {
    # Note: See NOTES.md regarding dynamic prevent_destroy in for_each blocks.
    prevent_destroy = true 
  }
}

# -------------------------------------------------------------
# Task 3: Multi-Account IAM & Cross-Account Access (Account A)
# -------------------------------------------------------------

# Users
resource "aws_iam_user" "engine" { name = "engine" }
resource "aws_iam_user" "ci" { name = "ci" }
resource "aws_iam_user" "user1" { name = "user1" }
resource "aws_iam_user" "user2" { name = "user2" }

# Group 1 (CLI/Programmatic only)
resource "aws_iam_group" "group1" { name = "group1" }
resource "aws_iam_group_membership" "group1_membership" {
  name  = "group1-members"
  group = aws_iam_group.group1.name
  users = [aws_iam_user.engine.name, aws_iam_user.ci.name]
}
# (Policy enforcing CLI-only omitted for brevity, usually done via aws:MultiFactorAuthPresent or denying console login)

# Group 2 (Console + CLI)
resource "aws_iam_group" "group2" { name = "group2" }
resource "aws_iam_group_membership" "group2_membership" {
  name  = "group2-members"
  group = aws_iam_group.group2.name
  users = [aws_iam_user.user1.name, aws_iam_user.user2.name]
}

# roleA: Admin access except IAM
resource "aws_iam_role" "roleA" {
  name = "roleA"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { AWS = "arn:aws:iam::000000000000:root" } }]
  })
}
resource "aws_iam_role_policy" "roleA_policy" {
  name = "AdminExceptIAM"
  role = aws_iam_role.roleA.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", NotAction = "iam:*", Resource = "*" }]
  })
}

# roleB: Can only assume roleC in Account B
resource "aws_iam_role" "roleB" {
  name = "roleB"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { AWS = "arn:aws:iam::000000000000:root" } }]
  })
}
resource "aws_iam_role_policy" "roleB_policy" {
  name = "AssumeRoleC"
  role = aws_iam_role.roleB.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Resource = "arn:aws:iam::111111111111:role/roleC" }]
  })
}
