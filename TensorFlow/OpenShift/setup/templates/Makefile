TEMPLATES_DIR=../../templates
NFD_TEMPLATES=$(TEMPLATES_DIR)/nfd
STANDARD_TEMPLATES=$(TEMPLATES_DIR)/standard

deploy:
	oc create -f $(NFD_TEMPLATES)/instance/buildconfig/base
	oc create -f $(NFD_TEMPLATES)/instance/buildconfig/s2i
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx/buildconfig
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx2/buildconfig
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx512/buildconfig
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx/benchmark/default
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx/benchmark/cpu_manager
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx2/benchmark/default
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx2/benchmark/cpu_manager
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx512/benchmark/default
	oc create -f $(NFD_TEMPLATES)/instruction_sets/avx512/benchmark/cpu_manager
	oc create -f $(STANDARD_TEMPLATES)

undeploy:
	oc delete -f $(NFD_TEMPLATES)/instance/buildconfig/base
	oc delete -f $(NFD_TEMPLATES)/instance/buildconfig/s2i
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx/buildconfig
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx2/buildconfig
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx512/buildconfig
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx/benchmark/default
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx/benchmark/cpu_manager
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx2/benchmark/default
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx2/benchmark/cpu_manager
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx512/benchmark/default
	oc delete -f $(NFD_TEMPLATES)/instruction_sets/avx512/benchmark/cpu_manager
	oc delete -f $(STANDARD_TEMPLATES)
