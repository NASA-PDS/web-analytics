# PDS Web Analytics Infrastructure

This Terraform module sets up infrastructure to ingest web analytics logs into OpenSearch Serverless using Logstash on an EC2 instance. The architecture and Web Analytics Tools installation steps can be found [HERE](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Platform)

---

## 📦 What This Deploys

- S3 bucket with:
  - Versioning
  - 30-day expiration lifecycle
  - Secure bucket policy
- S3 Bucket policy:
  - Full access for `mcp-tenantOperator`
  - Deny unencrypted (non-HTTPS) requests
- **Note** : AOSS (OpenSearch Serverless) collection, IAM instance profile and EC2 have already been deployed. Please view the following [Document](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Platform) to see the name of the resources that have already been configured.

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

**NOTE**: `.tfvars` does not get commited to github.

Create a file named `terraform.tfvars` in the root folder as per the env configurations provided [HERE](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Platform). Below is an EXAMPLE of what your `terraform.tfvars` should look like however the values will be different based on the which env you're deploying to. It's documented in the link above.

```hcl
tenant               = "tenant"
cicd                 = "cicd_value"
venue                = "venue_name"
component            = "Storage"
createdBy            = "test-email@nasa.gov"
vpc_id               = "vpc-12ab34dc56ef
pds_resource_prefix  = "resournce_prefix"
```

## Step 2 – Edit `backend.tfvars`

Edit `backend.tf` in the root folder as per the env configurations provided [HERE](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Platform). Below is an EXAMPLE of what your `backend.tf` should look like however the values will be different based on the which env you're deploying to. It's documented in the link above.

```hcl
terraform {
  backend "s3" {
    bucket = "bucket-name"
    key    = "key_name/some_state.tfstate"
    region = "us-west-2"
  }
}
```
## Step 3 – Deploy the Infrastructure

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

## Step 4 (Manual) - Verify EC2 IAM Role (Manual Check)

Ensure your EC2 instance is using the correct IAM role and instance profile:

- Role Name: [HERE](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Platform)
- Instance Profile: [HERE](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Platform)

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

## Step 5 (Manual) - Add IAM Intance Profile to OpenSearch Serverless

1. Go to AWS Console > Amazon OpenSearch Serverless

2. Select the collection: [Collection Name](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Platform)
3. Open the Data Access Policy within the collection above
4. Locate the correct rule where you want to add your EC2 profile permissions
5. Add this principal:
   ```
   arn:aws:iam::<your-account-id>:role/ec2_instance_profile
   ```
*Note*: The `ec2_instance_profile` name is documented [Instance Profile](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Platform)
6. Click Save

## Step 6 (Manual) - Install Web Analytics Components and Update LogStash Configuration

1. SSH into your EC2 instance where you have both logstash and Web Analytics Components installed.

The directions to install Web Analytics Tools and Logstash are provided [HERE](https://github.com/NASA-PDS/web-analytics/blob/main/README.md)

**Note**: For Dev and Prod environments we already have these [EC2 Instances](https://wiki.jpl.nasa.gov/display/PDSEN/Web+Analytics+Platform) that have both LogStash and Web Analytics Tools installed.

2. Follow steps provided on how to [Load Logs to S3 from PDS Reports](https://wiki.jpl.nasa.gov/display/PDSEN/ETL+Process+for+Web+Logs#ETLProcessforWebLogs-SyncLogstoS3).

*Restart LogStash*

```
sudo systemctl restart logstash
```

## Step 7 (Manual) - Web Analytics Dashboard Validation

Once Logs have been updated to PDS Web Analytics S3 bucket and Logstash has been restarted, you should now we able to access the **Web Analytics Dashboard** in Amazon OpenSearch Collection.

Access OpenSearch Collection > Dashboards > Web Analytics Dashboard

You should see log data being populated successfully.
