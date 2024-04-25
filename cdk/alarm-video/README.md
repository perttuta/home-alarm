# S3 infra for storing alarm video clips

This CDK deployment creates an S3 bucket for storing alarm video clips and a user, who is allowed to write those
videos. The user is also allowed to created signed URLs to videos for easier retrieval.

# Scripts
* `npm run build`   compile typescript to js
* `npm run watch`   watch for changes and compile
* `npm run test`    perform the jest unit tests
* `cdk deploy`      deploy this stack to your default AWS account/region
* `cdk diff`        compare deployed stack with current state
* `cdk synth`       emits the synthesized CloudFormation template

