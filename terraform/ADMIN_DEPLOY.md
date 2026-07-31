# Admin Deployment Steps

These steps require elevated IAM permissions (`iam:CreatePolicy`, `iam:AttachRolePolicy`, `iam:PassRole`) not available to `Project-Power-User`.

## Prerequisites

- Clone/pull the `terraform` branch of https://github.com/NASA-PDS/web-analytics
- `terraform` installed (`brew install terraform`)
- `go-task` installed (`brew install go-task/tap/go-task`)
- AWS profile with admin IAM permissions

## Step 1 — Create tfvars files

```bash
cd terraform/

cp iam/policies/tfvars/dev.tfvars.example iam/policies/tfvars/dev.tfvars
# edit managedby to your email

cp tfvars/dev.tfvars.example tfvars/dev.tfvars
# edit managedby to your email
# fill in vpc_id: vpc-02f8cc4962d6f8dc6
```

## Step 2 — Export AWS credentials

```bash
eval $(aws configure export-credentials --profile <your-admin-profile> --format env)
```

## Step 3 — Deploy IAM policy

```bash
task iam:plan   VENUE=dev
task iam:deploy VENUE=dev
```

## Step 4 — Deploy EC2

```bash
task ec2:plan   VENUE=dev
task ec2:deploy VENUE=dev
```

That's it — should take under 5 minutes total. Ping @jordan.h.padams if anything fails.
