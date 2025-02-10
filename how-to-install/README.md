![# TANDEM TARCE AWS INVDETIGATION ](http://tandemtrace.ai/wp-content/uploads/2025/02/tand3.png)



# AWSight-IR

AWSight-IR leverages AWS native services and APIs to maintain fast visibility of your cloud infrastructure while providing powerful incident response capabilities using AI. 
Adversaries use the same APIs and methods as administrators and developers, and so context would make a difference in classifying bad actors. 


## 🚀 What This Project Does


This proof-of-concept shows how to automate AWS context retrieval for IR and SecOps use cases—with AI-ready integration.



## How?

 - ✅ Uploads a Lambda function ZIP file to S3
 - ✅ Deploys the necessary AWS infrastructure using CloudFormation.
 - ✅ Invokes the Lambda function to fetch critical security data.
 - ✅ Retrieves and processes the latest IR data from S3.
 - ✅ Cleans up AWS resources automatically post-execution. 

🤓🔎 Start working with your context 



## 💡 Technical steps:

*Use this project from a dedicated Ubuntu VM. 

## Step 1 - install AWS cli and configure: 

```shell
# AWS CLI

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

```

```shell
# AWS configure permissions 

aws configure 

```


## Step 2 - Install AWSight-IR git repo:

```shell

git clone https://github.com/tandemtrace-ai/AWSight-IR.git
```

### Configuration files:

```shell

Web UI directories:
AWSight-IR/webui/.env

AI LLM API key:
AWSight-IR/webui/server/.env
```

### Fetch IR data:   

Check AWS necessary configurations: 

```shell
cd AWSight-IR/aws-ir
./verify_aws.sh
```

Execute the stack:

```shell
If verification was passed, run deployment:
./run-ir-full.sh
```


## Step 3 - Web user Interface: 

If you want your AI LLM API to be working, you need to configure the .env file under:
```shell
AWSight-IR/webui/server/.env
```

Then, to make it easy for the UI to run, we created a bash script that will install all packages, dependencies, and services to persist: 

```shell
sudo bash -x AWSight-IR/webui/setup_services_web.sh
```

Check services and installation:
```shell
sudo systemctl status awsight-web-front
sudo systemctl status awsight-web-backend
netstat -an | grep -E '8000|4173'
```


If you have configured and installed everything correctly, then you will have access to the following: 
```shell
http://x.x.x.x:4173/
```

### Verification: 

If the process is successful, then a JSON will be created with a unique timestamp like this:
```shell
AWSight-IR/aws-ir/ir_data_timestamp.json
```

Extra verifications and debugging:
```shell
You can run each bash script with verbose mode - bash -x file.sh
```

You also have log files to inspect under the - AWSight-IR/aws-ir:
```shell
deployment_timestamp.log
response.json
```


If you need to remove the services:
```shell
sudo bash -x ./remove_services_web.sh
```
