# Failed Release Test Chart

## Purpose
This chart tests detection of releases that fail due to image pull errors.

## Failure Mechanism
- Uses a non-existent container image
- Image pull policy set to "Always"
- Pod will be stuck in ImagePullBackOff state
- Deployment never becomes ready

## Expected Behavior
- Helm install may succeed (resources created)
- Pods show ImagePullBackOff or ErrImagePull status
- Events show image pull failures
- Application never becomes healthy
- `helm_release_debug.sh` should identify pod failures and image pull issues

## Test Usage
```bash
helm install test-failed ./failed-release -n helm-test-states --wait=false
```

## Cleanup
```bash
helm uninstall test-failed -n helm-test-states
kubectl delete pods -n helm-test-states --all
```
