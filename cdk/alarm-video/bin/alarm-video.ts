#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { AlarmVideoStack } from '../lib/alarm-video-stack';

const app = new cdk.App();
new AlarmVideoStack(app, 'AlarmVideoStack', {
  env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: 'eu-north-1' },
});