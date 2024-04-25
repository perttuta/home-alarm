import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';

export class AlarmVideoStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const bucket = new s3.Bucket(this, 'halyvideo-bucket', {
      bucketName: 'halyvideo',
      versioned: false,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    bucket.addLifecycleRule({
      enabled: true,
      expiration: cdk.Duration.days(14),
    });

    const user = new iam.User(this, 'alarm-video-user', {
      userName: 'alarm-video',
    });

    bucket.grantPut(user);
    user.addToPolicy(new iam.PolicyStatement({
      actions: ['s3:GetObject*'],
      resources: [bucket.bucketArn + '/*'],
    }));
  }
}
