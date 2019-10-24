REDHAT_IO_REGISTRY_SECRET_FILE=../../../../secrets/redhat_io_registry.yaml
REDHAT_IO_PULL_SECRET=$(shell while IFS=" " read -r t || [ -n "$$t" ]; do \
	    if [[ "$$t" == "name:"* ]]; then echo $$t | cut -d ' ' -f 2 && break; fi; \
done < "$(REDHAT_IO_REGISTRY_SECRET_FILE)")

OPENSHIFT_TOKEN=$(shell oc serviceaccounts get-token 'builder')

all: redhat_io_secret openshift_secret

redhat_io_secret:
	oc create -f $(REDHAT_IO_REGISTRY_SECRET_FILE) --namespace=openshift-image-registry
	oc secrets add serviceaccount/default secrets/$(REDHAT_IO_PULL_SECRET) --for=pull --namespace=openshift-image-registry

openshift_secret:
	oc project openshift-image-registry
	oc secrets new-dockercfg openshift-image-registry-pull-secret --docker-server=image-registry.openshift-image-registry.svc:5000 --docker-username=default --docker-password=$(OPENSHIFT_TOKEN) --docker-email=null

clean:
	oc delete -f $(REDHAT_IO_REGISTRY_SECRET_FILE)
	oc delete secret/openshift-image-registry-pull-secret
