kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: config-reader-rolebinding
  namespace: {{.Values.service.namespace}}
  labels:
    app: {{.Values.service.name}}
subjects:
- kind: Group
  name: system:serviceaccounts
  apiGroup: rbac.authorization.k8s.io
  namespace: {{.Values.service.namespace}}
roleRef:
  kind: Role
  name: config-reader
  apiGroup: ""