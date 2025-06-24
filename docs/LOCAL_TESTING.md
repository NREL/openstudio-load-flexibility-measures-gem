# Local Testing with Act

This document explains how to run the GitHub Actions workflow locally using [act](https://github.com/nektos/act) with proper AWS credentials.

## Prerequisites

1. **Install act**: Follow the [installation instructions](https://github.com/nektos/act#installation)
2. **Install Docker**: act requires Docker to run containers
3. **AWS Credentials**: You'll need valid AWS credentials with S3 access

## Quick Setup

### 1. Create Local Secrets File

Copy the example secrets file and fill in your credentials:

```bash
cp .secrets.example .secrets
```

Then edit `.secrets` with your actual AWS credentials:

```bash
# Your actual AWS credentials
AWS_ACCESS_KEY_ID=AKIA...your_actual_key
AWS_SECRET_ACCESS_KEY=your_actual_secret_key
AWS_DEFAULT_REGION=us-east-1
S3_BUCKET=your-actual-bucket-name
```

### 2. Run the Workflow

```bash
act
```

That's it! The workflow will:
- Use the OpenStudio 3.10.0 container
- Install Node.js and AWS CLI automatically
- Run the measures
- Upload results to S3 (if credentials are provided)
- Create local artifacts

## Alternative Methods

### Method 2: Command Line Secrets

```bash
act --secret AWS_ACCESS_KEY_ID=your_key \
    --secret AWS_SECRET_ACCESS_KEY=your_secret \
    --secret AWS_DEFAULT_REGION=us-east-1 \
    --secret S3_BUCKET=your-bucket
```

### Method 3: Environment Variables

```bash
act -e AWS_ACCESS_KEY_ID=your_key \
    -e AWS_SECRET_ACCESS_KEY=your_secret \
    -e AWS_DEFAULT_REGION=us-east-1 \
    -e S3_BUCKET=your-bucket
```

### Method 4: Custom Secrets File

```bash
act --secret-file /path/to/custom/secrets.env
```

## Security Best Practices

1. **Never commit `.secrets`**: This file is already in `.gitignore`
2. **Use IAM roles with minimal permissions**: Only grant S3 access needed
3. **Rotate credentials regularly**: Especially if they might be compromised
4. **Use temporary credentials**: Consider AWS STS for temporary access

## Troubleshooting

### Common Issues

**Error: "Input required and not supplied: aws-region"**
- Solution: Make sure all required secrets are in your `.secrets` file

**Error: "docker: command not found"**
- Solution: Install Docker and ensure it's running

**Error: "act: command not found"**
- Solution: Install act following the official installation guide

### Debugging

Run with verbose output:
```bash
act --verbose
```

Run specific job:
```bash
act -j test-gems-latest
```

## What Gets Tested

The local workflow tests:
1. ✅ OpenStudio environment setup
2. ✅ Measure execution with verbose output
3. ✅ AWS credentials configuration (if provided)
4. ✅ S3 file upload (if credentials provided)
5. ✅ Artifact creation

## Expected Output

When successful, you should see:
- OpenStudio version information
- Ruby version information
- Measure execution logs
- Test results in `./test` directory
- S3 upload confirmation (if configured)
- Artifact creation confirmation
