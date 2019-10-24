TEMPLATES_DIR=../../templates
NFD_TEMPLATES=$(TEMPLATES_DIR)/nfd
STANDARD_TEMPLATES=$(TEMPLATES_DIR)/standard

deploy:
	oc create -f $(NFD_TEMPLATES)/instance/buildconfig
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx/buildconfig
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx2/buildconfig
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx512/buildconfig
	oc create -f $(NFD_TEMPLATES)/instruction_sets/no_avx/buildconfig
	oc create -f $(NFD_TEMPLATES)/instance/job/default
	oc create -f $(NFD_TEMPLATES)/instance/job/gpu
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx/job/default
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx/job/cpu_manager
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx2/job/default
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx2/job/cpu_manager
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx512/job/default
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx512/job/cpu_manager
	oc create -f $(STANDARD_TEMPLATES)

undeploy:
	oc delete -f $(NFD_TEMPLATES)/instance/buildconfig
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx/buildconfig
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx2/buildconfig
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx512/buildconfig
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/no_avx/buildconfig
	oc delete -f $(NFD_TEMPLATES)/instance/job/default
	oc delete -f $(NFD_TEMPLATES)/instance/job/gpu
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx/job/default
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx/job/cpu_manager
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx2/job/default
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx2/job/cpu_manager
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx512/job/default
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx512/job/cpu_manager
	oc delete -f $(STANDARD_TEMPLATES)
