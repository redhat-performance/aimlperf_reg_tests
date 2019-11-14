# 'AWS_DIR' is the path to the '.aws' folder. e.g., '~/.aws'. 'AWS_PROFILE' is the AWS profile to use

all: generate_aws_env

generate_aws_env:
	sh generate_aws_env_file.sh $(AWS_DIR)/credentials $(AWS_DIR)/config $(AWS_PROFILE) $(CUDNN) $(NCCL) $(TENSORRT)

clean:
	rm ../aws_env.sh
