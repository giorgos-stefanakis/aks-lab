kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: aks-lab
nodes:
  - role: control-plane
    image: kindest/node:v1.37.0
    # kubeadm keeps key files that already exist, so these mounts replace its generated pair.
    extraMounts:
      - hostPath: @OIDC_DIR@/sa.key
        containerPath: /etc/kubernetes/pki/sa.key
        readOnly: true
      - hostPath: @OIDC_DIR@/sa.pub
        containerPath: /etc/kubernetes/pki/sa.pub
        readOnly: true
kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiVersion: kubeadm.k8s.io/v1beta4
    apiServer:
      extraArgs:
        - name: service-account-issuer
          value: @ISSUER@
        - name: service-account-jwks-uri
          value: @ISSUER@/openid/v1/jwks
