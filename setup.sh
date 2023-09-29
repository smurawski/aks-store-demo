deployment_name="aksstoreai2"

RESOURCE_GROUP=$(az deployment sub show --name $deployment_name --query "properties.outputs.resourceGroup.value" -o tsv)
CLUSTER_NAME=$(az deployment sub show --name $deployment_name --query "properties.outputs.aksName.value" -o tsv)
MANAGED_IDENTITY_CLIENT_ID=$(az deployment sub show --name $deployment_name --query "properties.outputs.workloadIdentity.value" -o tsv)
SERVICE_ACCOUNT_NAME='workload-identity-sa'
SERVICE_ACCOUNT_NAMESPACE='default'
AOAI_DEPLOYMENT_NAME='gpt-35-turbo'
AOAI_ENDPOINT=$(az deployment sub show --name $deployment_name --query "properties.outputs.aiEndpoint.value" -o tsv)

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing
kubectl apply -f ./aks-store-all-in-one.yaml

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${MANAGED_IDENTITY_CLIENT_ID}
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ai-service
  template:
    metadata:
      labels:
        app: ai-service
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: $SERVICE_ACCOUNT_NAME
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
      - name: ai-service
        image: ghcr.io/azure-samples/aks-store-demo/ai-service:latest
        ports:
        - containerPort: 5001
        env:
        - name: USE_AZURE_OPENAI
          value: "True"
        - name: USE_AZURE_AD
          value: "True"
        - name: AZURE_OPENAI_DEPLOYMENT_NAME
          value: "${AOAI_DEPLOYMENT_NAME}"
        - name: AZURE_OPENAI_ENDPOINT
          value: "${AOAI_ENDPOINT}"
        resources:
          requests:
            cpu: 20m
            memory: 50Mi
          limits:
            cpu: 30m
            memory: 65Mi
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ai-service
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 5001
    targetPort: 5001
  selector:
    app: ai-service
EOF

store_admin_ip=$(kubectl get service store-admin -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
store_front_ip=$(kubectl get service store-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Store Admin: http://${store_admin_ip}"
echo "Store Front: http://${store_front_ip}"