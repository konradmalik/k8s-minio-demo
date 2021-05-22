MINIO_TENANT_NAME=minio-tenant


k3d-create:
	k3d cluster create --config k3d.yaml

k3d-delete:
	k3d cluster delete ${MINIO_TENANT_NAME}

krew-install-minio:
	kubectl krew update \
	&& kubectl krew install minio

minio-create: export CLUSTER_NAME=${MINIO_TENANT_NAME}
minio-create:
	kubectl create namespace ${MINIO_TENANT_NAME} --dry-run=client -o yaml | kubectl apply -f - \
	&& cd minio \
	; kubectl minio init \
	; envsubst < minio.yaml | kubectl apply --namespace ${MINIO_TENANT_NAME} --filename - \

minio-delete: export CLUSTER_NAME=${MINIO_TENANT_NAME}
minio-delete:
	kubectl minio tenant delete ${MINIO_TENANT_NAME} --namespace ${MINIO_TENANT_NAME} \
	; cd minio \
	&& envsubst < minio.yaml | kubectl delete --namespace ${MINIO_TENANT_NAME} --filename - \
	; kubectl delete pvc,csr -l v1.min.io/tenant=${MINIO_TENANT_NAME} -n ${MINIO_TENANT_NAME} \

minio-server-port-forward:
	kubectl port-forward -n ${MINIO_TENANT_NAME} service/minio 8443:443

minio-console-port-forward:
	kubectl port-forward -n ${MINIO_TENANT_NAME} service/minio-tenant-console 9443:9443

minio-operator-port-forward:
	kubectl minio proxy

minio-mc:
	kubectl run -i --rm --tty mc --image=minio/mc:RELEASE.2021-03-10T05-59-20Z \
		--namespace=${MINIO_TENANT_NAME} \
		--env=MC_HOST_demo=https://minio:minio123@minio:443 \
		--restart=Never --command -- sh
