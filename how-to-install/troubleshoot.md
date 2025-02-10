
### Troubleshooting: 

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
