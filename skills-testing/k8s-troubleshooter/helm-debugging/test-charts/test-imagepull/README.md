# TF-003: Test Pod ImagePullBackOff Test Chart

## Purpose

This chart tests detection when a test pod cannot pull its image.

## Failure Mechanism

The test pod uses a non-existent image (`nonexistent-registry.example.com/test-image:does-not-exist`), causing ImagePullBackOff and preventing the test from running.

## Usage

```bash
# Deploy chart successfully
helm install test-imagepull ./test-imagepull -n helm-test-tests

# Wait for app deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-tests --timeout=60s

# Attempt helm test (will fail due to image pull)
helm test test-imagepull -n helm-test-tests --logs

# Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-imagepull helm-test-tests --run-tests
```

## Expected Behavior

- App deploys successfully
- Test pod shows ImagePullBackOff or ErrImagePull
- Events show image pull errors
- Test never runs
- Script identifies image pull issue

## Validation

```bash
# Verify test pod in ImagePullBackOff
kubectl get pods -n helm-test-tests -l "helm.sh/hook=test"

# Check events for image pull errors
kubectl get events -n helm-test-tests --sort-by='.lastTimestamp' | grep -i "pull\|image"

# Describe test pod
kubectl describe pod -n helm-test-tests -l "helm.sh/hook=test" | grep -A 5 Events
```

## Cleanup

```bash
kubectl delete pods -n helm-test-tests -l "helm.sh/hook=test"
helm uninstall test-imagepull -n helm-test-tests
```
