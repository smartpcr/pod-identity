kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: config-reader
  namespace: {{.Values.service.namespace}}
  labels:
    app: {{.Values.service.name}}
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
