HOME_DIR=${HOME}

all: update_yamls add_secrets

update_yamls:
	sh update_secret_yamls.sh $(HOME_DIR)/.aws/credentials $(HOME_DIR)/.aws/config $(PROFILE)

add_secrets:
	kubectl apply -f credentials_secret.yaml
	kubectl apply -f config_secret.yaml

clean:
	kubectl delete secret/aws-credentials
	kubectl delete secret/aws-config
