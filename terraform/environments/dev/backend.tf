terraform {
  backend "s3" {
    # Uncomment and match bucket name created in init-backend.sh: "terraform-state-<ACCOUNT_ID>-<REGION>"
    # bucket       = "terraform-state-<ACCOUNT_ID>-<REGION>" 
    # Or pass at terraform init with: -backend-config="bucket=terraform-state-<ACCOUNT_ID>-<REGION>"

    key          = "wordpress/dev/terraform.tfstate"
    region       = "eu-central-1" # Replace with the actual region
    encrypt      = true
    use_lockfile = true
  }
}