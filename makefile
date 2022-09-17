NAMESPACE=coreader-argo
SERVICE_ACCOUNT=coreader-argo
DEPLOYMENT_DIR=deployment
DEPLOYMENT_NS=${DEPLOYMENT_DIR}/.${NAMESPACE}

ARGO_HOST_DOMAIN=public.example.com

LOCAL_PATH_NODE=main-node-hostname
LOCAL_PATH_REDIS=/volume/redis
LOCAL_PATH_MONGO=/volume/mongo

############################################
############################################

kustomize:
	@if [ -d "${DEPLOYMENT_NS}" ]; then \
		rm -r "${DEPLOYMENT_NS}"; \
	fi \

	@mkdir -p "${DEPLOYMENT_NS}" \

	@for FILE in ${DEPLOYMENT_DIR}/*; do \
		sed -e "s:{{NAMESPACE}}:${NAMESPACE}:g" \
			-e "s:{{USER}}:${SERVICE_ACCOUNT}:g" \
			-e "s:{{ARGO_HOST_DOMAIN}}:${ARGO_HOST_DOMAIN}:g" \
			-e "s:{{LOCAL_PATH_NODE}}:${LOCAL_PATH_NODE}:g" \
			-e "s:{{LOCAL_PATH_REDIS}}:${LOCAL_PATH_REDIS}:g" \
			-e "s:{{LOCAL_PATH_MONGO}}:${LOCAL_PATH_MONGO}:g" \
			"$$FILE" > "${DEPLOYMENT_NS}/$$(basename $$FILE)"; \
	done

check: 
	@if [ ! -d "${DEPLOYMENT_NS}" ]; then \
		echo "Path ${DEPLOYMENT_NS} doesn't exist. (kustomize first)"; \
		exit 1; \
	fi

uninstall:
	-helm uninstall -n $(NAMESPACE) argo  
	-@kubectl delete -f $(DEPLOYMENT_NS)
	-kubectl get crd | grep 'argoproj.io' | awk '{print $1}' | xargs kubectl delete crd

	-@rm -r $(DEPLOYMENT_NS)


install: kustomize
	@sh ./scripts/install.sh "$(NAMESPACE)" "${DEPLOYMENT_NS}"
	$(MAKE) createToken

	
createToken: check
	kubectl apply -f $(DEPLOYMENT_NS)/argo-rbac.yaml
	@ARGO_TOKEN="Bearer "$$(kubectl -n $(NAMESPACE) get secret $(SERVICE_ACCOUNT).service-account-token -o=jsonpath='{.data.token}' | base64 --decode) && \
	echo "export ARGO_TOKEN=\"$$ARGO_TOKEN\"" > config.sh
	@echo "export ARGO_NAMESPACE=$(NAMESPACE)" >> config.sh
	@cat config.sh


upgrade: check
	helm upgrade -n $(NAMESPACE) argo argo/argo-workflows --debug -f $(DEPLOYMENT_NS)/argo-values.yaml 


deploy: check
	kubectl apply -f $(DEPLOYMENT_NS)/mongo.yaml
	kubectl apply -f $(DEPLOYMENT_NS)/redis.yaml

delete: check
	-kubectl delete -f $(DEPLOYMENT_NS)/mongo.yaml
	-kubectl delete -f $(DEPLOYMENT_NS)/redis.yaml
	
	
deploy_jupyter: check
	kubectl apply -f $(DEPLOYMENT_NS)/jupyter.yaml
	until kubectl get pods -n $(NAMESPACE) -l app=jupyter -o jsonpath="{.items[0].status.phase}" | grep Running ; do sleep 1 ; done
	@POD=$$(kubectl -n $(NAMESPACE) get pods -l app=jupyter -o jsonpath='{.items[0].metadata.name}'); \
	TOKEN=""; \
	END=$$(date -ud "5 minutes" +%s); \
	while [ -z "$$TOKEN" ]; do \
	  CURRENT=$$(date +%s); \
	  if [ $$CURRENT -ge $$END ]; then \
	    echo "Timeout waiting for Jupyter token."; \
	    exit 1; \
	  fi; \
	  sleep 1; \
	  TOKEN=$$(kubectl -n $(NAMESPACE) exec $$POD -- jupyter notebook list | grep -oP '(?<=token=)[^ ]*' | head -1); \
	done; \
	echo "http://$(ARGO_HOST_DOMAIN):48081/?token=$$TOKEN"

	
delete_jupyter: check
	-kubectl delete -f $(DEPLOYMENT_NS)/jupyter.yaml
	