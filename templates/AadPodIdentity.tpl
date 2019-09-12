apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: {{.Values.identity.name}}
spec:
  type: 0
  ResourceID: {{.Values.serviceIdentity.id}}
  ClientId: {{.Values.serviceIdentity.clientId}}