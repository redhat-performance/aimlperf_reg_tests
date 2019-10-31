
CONFIG = $(KUBECONFIG)

all: secrets cuda_rhel7

secrets:
	$(MAKE) -f Makefile.secrets

cuda_rhel7:
	$(MAKE) KUBECONFIG=$(CONFIG) -f Makefile.cuda_rhel7

cuda_rhel8:
	$(MAKE) KUBECONFIG=$(CONFIG) -f Makefile.cuda_rhel8

clean:
	$(MAKE) -f Makefile.secrets clean
	$(MAKE) -f Makefile.cuda_rhel7 clean
	$(MAKE) -f Makefile.cuda_rhel8 clean
