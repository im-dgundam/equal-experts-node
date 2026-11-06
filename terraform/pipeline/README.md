# terraform/pipeline

Terraform manifests that provision the AWS delivery pipeline for the Gists API server.

---

## Resources created

| Resource | AWS service | Purpose |
|----------|-------------|---------|
| `aws_ecr_repository` | ECR | Stores Docker images |
| `aws_ecr_lifecycle_policy` | ECR | Expires old/untagged images automatically |
| `aws_codepipeline` | CodePipeline | Orchestrates the four-stage delivery pipeline |
| `aws_codebuild_project` | CodeBuild | Runs load tests against staging |
| `aws_s3_bucket` | S3 | Pipeline artifact store |
| `aws_sns_topic` | SNS | Notifies approvers before the production stage |
| `aws_iam_role` × 2 | IAM | Least-privilege roles for CodePipeline and CodeBuild |

---

## Pipeline flow

```
┌──────────┐    ┌────────────────────────────────────┐    ┌─────────────────┐    ┌────────────┐
│  Source  │───►│             Staging                │───►│    Approve      │───►│ Production │
│          │    │  Deploy-Staging ──► Load-Test       │    │ (manual gate)   │    │   Deploy   │
│ ECR push │    │  (ECS rolling)     (CodeBuild)      │    │                 │    │  (ECS)     │
└──────────┘    └────────────────────────────────────┘    └─────────────────┘    └────────────┘
```

### Stage details

| Stage | Action | Type | Trigger / condition |
|-------|--------|------|---------------------|
| **Source** | ECR-Image | ECR source | New image pushed with tag `latest` |
| **Staging** | Deploy-Staging | ECS rolling deploy | Automatic after source |
| **Staging** | Load-Test | CodeBuild | Runs after Deploy-Staging (`run_order = 2`) |
| **Promote** | Manual-Approval | Approval gate | SNS email sent; human must approve |
| **Production** | Deploy-Production | ECS rolling deploy | Runs only after approval |

---

## File layout

```
terraform/pipeline/
├── versions.tf           # Terraform and provider version constraints
├── variables.tf          # All input variables with descriptions and defaults
├── ecr.tf                # ECR repository and lifecycle policy
├── iam.tf                # IAM roles, S3 artifact bucket, SNS topic
├── codebuild.tf          # CodeBuild load-test project and CloudWatch log group
├── codepipeline.tf       # CodePipeline with all four stages
├── outputs.tf            # Useful outputs (ECR URL, pipeline ARN, etc.)
├── terraform.tfvars.example  # Template – copy to terraform.tfvars
└── README.md
```

---

## Prerequisites

- Terraform >= 1.6
- AWS credentials with permissions to manage ECR, CodePipeline, CodeBuild, S3, SNS, and IAM
- The ECS clusters and services referenced in variables must already exist (this module does not create them)
- A `locustfile.py` in a `loadtest/` directory at the repository root (used by the CodeBuild load-test stage)

---

## Usage

```bash
cd terraform/pipeline

# Copy and fill in variable values
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

terraform init
terraform plan
terraform apply
```

### Storing state remotely (recommended)

Add an S3 backend block to `versions.tf` before running `init`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-tfstate-bucket"
    key            = "gists-api/pipeline/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "your-tfstate-lock-table"
    encrypt        = true
  }
}
```

---

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `aws_region` | AWS region | `eu-west-1` |
| `project` | Resource name prefix | `gists-api` |
| `staging_cluster_name` | ECS staging cluster | _(required)_ |
| `staging_service_name` | ECS staging service | _(required)_ |
| `staging_task_definition_family` | Staging task definition family | _(required)_ |
| `production_cluster_name` | ECS production cluster | _(required)_ |
| `production_service_name` | ECS production service | _(required)_ |
| `production_task_definition_family` | Production task definition family | _(required)_ |
| `container_name` | Container name in the task definition | `gists-api` |
| `staging_url` | Base URL of the staging service for load tests | _(required)_ |
| `pipeline_approval_email` | Email for approval SNS notifications | `""` (disabled) |
| `ecr_untagged_expiry_days` | Days before untagged images are deleted | `14` |
| `load_test_buildspec` | Inline buildspec YAML for load tests | Locust 60 s run |

## Outputs

| Name | Description |
|------|-------------|
| `ecr_repository_url` | Full ECR URL — use in the GitHub Actions push step |
| `ecr_repository_arn` | ECR repository ARN |
| `pipeline_name` | CodePipeline name |
| `pipeline_arn` | CodePipeline ARN |
| `codebuild_project_name` | Load-test CodeBuild project name |
| `artifact_bucket_name` | S3 artifact bucket name |
| `approval_sns_topic_arn` | SNS topic ARN for manual approval |

---

## Connecting the GitHub Actions CI workflow

After `terraform apply`, wire the ECR push step into the existing CI workflow:

1. Copy the `ecr_repository_url` output value.
2. Add the following secrets to your GitHub repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY` (or use OIDC — preferred for production)
3. Add a **push** job to `.github/workflows/ci.yml` that runs after the **scan** job:

```yaml
push:
  name: Push to ECR
  runs-on: ubuntu-latest
  needs: scan
  if: github.ref == 'refs/heads/main'

  steps:
    - uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: eu-west-1

    - name: Log in to ECR
      uses: aws-actions/amazon-ecr-login@v2

    - name: Download image tarball
      uses: actions/download-artifact@v4
      with:
        name: docker-image
        path: /tmp

    - name: Load and push image
      run: |
        docker load --input /tmp/image.tar
        docker tag gists-api-server:main <ecr_repository_url>:latest
        docker push <ecr_repository_url>:latest
```

Pushing `latest` to ECR triggers the CodePipeline source stage automatically.

---

## Load test customisation

The default buildspec installs [Locust](https://locust.io/) and expects a `loadtest/locustfile.py` at the repository root. Override the `load_test_buildspec` variable to use a different tool (e.g. k6, Artillery) or point at a different file path.

---

## Security notes

- ECR push-time scanning (`scan_on_push = true`) is enabled. Review findings in the ECR console under *Vulnerabilities*.
- The S3 artifact bucket has public access blocked and server-side encryption enabled.
- IAM roles follow least-privilege: CodeBuild cannot deploy to ECS; CodePipeline cannot write CloudWatch logs.
- The manual approval gate ensures no unreviewed change reaches production automatically.
