# DevOps Assignment Notes

## Task 1: Lifecycle Block & Accidental Deletion
**Which instance is protected and why?**
I chose to protect the `db-server`. A database server holds persistent, stateful data. While replacing stateless web servers or worker nodes is trivial in a cloud environment, destroying the DB instance leads to immediate data loss and a major outage. 

**Terraform Limitation Note:** Because Terraform does not allow dynamic values inside the `lifecycle { prevent_destroy = true }` block, applying this inside a `for_each` resource protects the *entire map* (all 5 instances) from being deleted by Terraform. If you strictly need to protect just one instance dynamically without separating the resource blocks, the AWS-native solution is to map `disable_api_termination = each.value.protected` on the EC2 resource itself, rather than using a Terraform `lifecycle` block. 

## Task 2: Remote State & Locking
**What happens with local state?**
If two engineers run `terraform apply` concurrently with local state, they will encounter a race condition. Terraform A and Terraform B will both read their local copies, make infrastructure changes independently, and overwrite each other. This results in duplicate resources, corrupted infrastructure mapping, and orphaned resources.

**How the S3/DynamoDB backend fixes it:** 
DynamoDB provides a state lock (a mutex). When Engineer A runs `apply`, Terraform acquires a lock in the DynamoDB table. If Engineer B runs `apply` simultaneously, Terraform checks DynamoDB, sees the active lock, and aborts (or waits), safely preventing concurrent state mutations.

## Task 3: Multi-Account IAM & Cross-Account Access
**1. Would you use static access keys for `engine` and `ci` in production?**
No, I would never use static long-lived IAM access keys for machines or CI/CD pipelines in a modern production setup.
*   **For `ci` (GitHub Actions, GitLab, etc.):** I would use OIDC (OpenID Connect). The CI provider authenticates directly with AWS to assume a role and receive short-lived STS credentials. 
*   **For `engine` (EC2, ECS, Lambda):** I would attach an IAM Instance Profile (for EC2) or Task Role (for ECS). The AWS hypervisor injects temporary, auto-rotating credentials directly into the compute environment via the metadata service. This entirely eliminates the risk of hardcoded, leaked `.csv` key files.

**2. Root vs ARN in roleC's trust policy**
*   **Trusting the Root (`arn:aws:iam::000000000000:root`):** This delegates trust to Account A's IAM administrators. *Any* IAM user or role in Account A could assume `roleC` if Account A's admin grants them the `sts:AssumeRole` permission.
*   **Trusting the ARN (`arn:aws:iam::000000000000:role/roleB`):** This establishes a hard, explicit boundary. AWS will *only* allow `roleB` to assume `roleC`. Even if an admin in Account A gives `sts:AssumeRole` to another user, AWS Account B will reject the request. This enforces strict least privilege across account boundaries.

## Task 4: Least-Privilege Policy Writing
**What was deliberately left out and why:**
*   **`ecr:*` or `ecs:*` wildcards:** Left out to prevent the CI pipeline from deleting the ECR repository, modifying cluster settings, or deleting existing services.
*   **`s3:PutObject`:** The prompt explicitly stated the CI pipeline only needs to *read* artifacts, so write/delete permissions were excluded to protect artifact integrity.
*   **Broad `iam:PassRole`:** If you deploy an ECS task, ECS must assume a role on behalf of the task. If you grant `iam:PassRole` broadly, a compromised CI pipeline could pass `AdministratorAccess` to an ECS task and run a reverse shell. The policy strictly limits `iam:PassRole` to only the specific `ecsTaskRole` required by the application.

## Task 5: Find and Fix the Bug
**Why the snippet failed (The two bugs):**

1.  **Trust Policy Bug:** 
    *   *Broken code:* `identifiers = ["arn:aws:iam::000000000000:user/roleB"]`
    *   *Why:* `roleB` is an IAM Role, not an IAM User. The ARN structure for roles uses `/role/`, not `/user/`. AWS would reject this trust policy.
    *   *Fix:* Change to `arn:aws:iam::000000000000:role/roleB`.
2.  **Permissions Policy Bug:**
    *   *Broken code:* `Action = "s3:*"`, `Resource = "*"`
    *   *Why:* The prompt explicitly stated `roleC` should have full access to a **single named S3 bucket**. Granting `Resource = "*"` gives full access to *every* S3 bucket in Account B, violating the security requirement.
    *   *Fix:* Constrain the Resource block to `["arn:aws:s3:::NAMED_BUCKET", "arn:aws:s3:::NAMED_BUCKET/*"]`.

**Fixed Code Block:**
```hcl
data "aws_iam_policy_document" "roleC_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      # FIX 1: Changed "user" to "role"
      identifiers = ["arn:aws:iam::000000000000:role/roleB"]
    }
  }
}

resource "aws_iam_role" "roleC" {
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.roleC_trust.json
}

resource "aws_iam_role_policy" "roleC_s3" {
  name = "roleC-s3-access"
  role = aws_iam_role.roleC.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:*"
      # FIX 2: Constrained Resource to a single specific bucket
      Resource = [
        "arn:aws:s3:::my-named-bucket",
        "arn:aws:s3:::my-named-bucket/*"
      ]
    }]
  })
}
