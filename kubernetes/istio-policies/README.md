# Istio Security Policies

This directory captures the baseline Istio resources required to enforce mutual TLS (mTLS) and workload-to-workload authorization. Apply these manifests via your preferred GitOps/tooling pipeline.

## Files

- `staging-peer-authentication.yaml` – Enables strict mTLS for the `academy-api-staging` and `brain-service-staging` namespaces.
- `staging-authorization-policy.yaml` – Restricts traffic so only approved workloads can call services within the `brain-service-staging` namespace.

## Usage

```bash
kubectl apply -f staging-peer-authentication.yaml
kubectl apply -f staging-authorization-policy.yaml
```

> Ensure Istio sidecar injection is enabled for the target namespaces prior to applying these policies.

## Next Steps

- Add production equivalents once staging rollout is validated.
- Integrate with CI to lint policies (`istioctl analyze`).
- Expand authorization policies to cover additional service-to-service pathways.
