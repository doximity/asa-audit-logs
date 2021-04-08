# asa-audit-logs

Terraform module that scans the Okta ASA Audit Events API on a scheduled basis.

## Description

This Terraform module creates an AWS Lambda which executes on schedule. This lambda then scans the Okta ASA API to to read Audit Events and output to CloudWatch.

An ASA service user with API keypair secrets stored in SSM is needed to run this module.

## Usage

```hcl
module "asa_audit_logs" {
  source = "git::https://github.com/doximity/asa-audit-logs?ref=tags/0.1.0"
  
  env   					= "production"
  asa_team 				= "demo_team"
  kms_key_arn 			= aws_kms_key.demo_key.arn
  asa_api_key_path 		= "/demo/asa/api_key"
  asa_api_secret_path 	= "/demo/asa/api_secret"
  time_interval = 15
}

```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/asa-audit-logs/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
6. Sign the CLA if you haven't yet. See CONTRIBUTING.md

## License

asa-audit-logs is licensed under an Apache 2 license. Contributors are required to sign an contributor license agreement. See LICENSE.txt and CONTRIBUTING.md for more information.
