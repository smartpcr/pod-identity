apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: "{{.Values.service.name}}"
    aadpodidbinding: "{{.Values.identity.name}}"
  name: {{.Values.service.name}}
  namespace: {{.Values.service.namespace}}
spec:
  template:
    metadata:
      labels:
        app: {{.Values.service.name}}
        aadpodidbinding: {{.Values.identity.name}}
    spec:
      containers:
      - name: {{.Values.service.name}}
        image: "{{.Values.acr.name}}.azurecr.io/{{.Values.service.image.name}}:{{.Values.service.image.tag}}"
        imagePullPolicy: Always
        resources:
          requests:
            memory: "200Mi"
            cpu: "100m"
          limits:
            memory: "800Mi"
            cpu: "750m"
        securityContext:
          capabilities:
            drop:
            - all
        ports:
          - containerPort: 6010
            protocol: TCP
        args:
          - "--subscriptionid={{.Values.global.subscriptionId}}"
          - "--clientid={{.Values.serviceIdentity.clientId}}"
          - "--resourcegroup={{.Values.serviceIdentity.resourceGroup}}"
          - "--aad-resourcename=https://vault.azure.net"
        env:
          - name: MY_POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: MY_POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: MY_POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP

      imagePullSecrets:
        - name: acr-auth
---
apiVersion: v1
kind: Service
metadata:
  name: "{{.Values.service.name}}"
  namespace: default
spec:
  ports:
  - protocol: TCP
    port: 443
    targetPort: 6010
    name: "{{.Values.service.name}}-https"
  selector:
    app: "{{.Values.service.name}}"
---
kind: Ingress
apiVersion: extensions/v1beta1
metadata:
  name: "{{.Values.service.name}}"
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: "/"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  tls:
  - hosts:
    - "{{.Values.service.name}}-{{.Values.global.envName}}.{{ .Values.dns.domain }}"
    secretName: "{{ .Values.dns.sslCert }}"
  rules:
  - host: "{{.Values.service.name}}-{{.Values.global.envName}}.{{ .Values.dns.domain }}"
    http:
      paths:
      - path: "/"
        backend:
          serviceName: "{{.Values.service.name}}"
          servicePort: 443