# PDS Web Analytics Infrastructure

This Terraform module sets up infrastructure to ingest web analytics logs into OpenSearch Serverless using Logstash on an EC2 instance. The architecture and Web Analytics Tools installation steps can be found [HERE](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Tools+Deployment)

---

## 📦 What This Deploys

- S3 bucket with:
  - Versioning
  - 30-day expiration lifecycle
  - Secure bucket policy
- S3 Bucket policy:
  - Full access for `mcp-tenantOperator`
  - Deny unencrypted (non-HTTPS) requests
- **Note** : AOSS (OpenSearch Serverless) collection, IAM instance profile and EC2 have already been deployed. Please view the following [Document](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Tools+Deployment) to see the name of the resources that have already been configured.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- AWS CLI configured
- Access to:
  - EC2 instance running Logstash
  - OpenSearch Serverless Console
  - IAM permissions to attach roles and update policies

---

## Step 1 – Create `terraform.tfvars`

Create a file named `terraform.tfvars` in the root folder (this will not be committed):

```hcl
tenant               = "en"
cicd                 = "pds-github-oidc"
venue                = "pds-mcp-dev"
component            = "Storage"
createdBy            = "pds-operator@jpl.nasa.gov"
vpc_id               = "vpc-12ab34dc56ef
pds_resource_prefix  = "pds-dev-gh01dc"
```

## Step 2 – Deploy the Infrastructure

Run the following :

```
terraform init
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
After applying, Terraform will output key values such as:
- S3 bucket name
- S3 bucket ARN

## Step 3 (Manual) - Verify EC2 IAM Role (Manual Check)

Ensure your EC2 instance is using the correct IAM role and instance profile:

- Role Name: [HERE](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Tools+Deployment)
- Instance Profile: [HERE](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Tools+Deployment)

You can verify this in the EC2 Console or CLI.

To attach manually using AWS CLI(if needed):

```
aws ec2 associate-iam-instance-profile \
  --instance-id <your-instance-id> \
  --iam-instance-profile Name=<ec2_instance_profile>
```

Via Console ...

1. Go to EC2 Console
2. Select your instance
3. Click Actions > Security > Modify IAM Role
4. Attach the EC2 instance profile created

## Step 4 (Manual) - Add IAM Intance Profile to OpenSearch Serverless

1. Go to AWS Console > Amazon OpenSearch Serverless

2. Select the collection: [Collection Name](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Tools+Deployment)
3. Open the Data Access Policy within the collection above
4. Locate the correct rule where you want to add your EC2 profile permissions
5. Add this principal:
   ```
   arn:aws:iam::<your-account-id>:role/ec2_instance_profile
   ```
*Note*: The `ec2_instance_profile` name is documented [Instance Profile](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Tools+Deployment)
6. Click Save

## Step 5 (Manual) - Install Web Analytics Components and Update LogStash Configuration

1. SSH into your EC2 instance where you have both logstash and Web Analytics Components installed.

The directions to install Web Analytics Tools are provided [HERE](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Tools+Deployment)

**Note**: For Dev and Prod environments we already have these [EC2 Instances](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Tools+Deployment) that have both LogStash and Web Analytics Tools installed.

2. Follow steps provided on how to [Load Logs to S3](https://wiki.jpl.nasa.gov/display/PDSEN/ETL+Process+for+Web+Logs#ETLProcessforWebLogs-SyncLogstoS3). Update logstash with S3 bucket name created as part of this terraform script in the input block.

*Input Block*

```
input {
  s3 {
    bucket => "pds-web-analytics-<env>"
    region => "us-west-2"
    codec => "json"
    aws_credentials_provider => "InstanceProfileCredentialsProvider"
  }
}
```

*Restart LogStash*

```
sudo systemctl restart logstash
```

