# Storage and CSI Troubleshooting

Comprehensive guide for diagnosing Persistent Volume (PV), Persistent Volume Claim (PVC), and Container Storage Interface (CSI) issues.

## Table of Contents

- [Storage Basics](#storage-basics)
- [PVC Lifecycle](#pvc-lifecycle)
- [PV and PVC Binding](#pv-and-pvc-binding)
- [StorageClass Troubleshooting](#storageclass-troubleshooting)
- [CSI Driver Issues](#csi-driver-issues)
- [Volume Attachment Problems](#volume-attachment-problems)
- [Mount Failures](#mount-failures)
- [Cloud Provider Specifics](#cloud-provider-specifics)
- [Performance Issues](#performance-issues)

## Storage Basics

### Storage Architecture

```
Pod → PVC → PV → CSI Driver → Cloud Provider Storage
```

**Components**:
- **PVC** (Persistent Volume Claim): Request for storage by user
- **PV** (Persistent Volume): Actual storage resource
- **StorageClass**: Template for dynamic provisioning
- **CSI Driver**: Interface between Kubernetes and storage backend

### Initial Investigation

```bash
# Check PVC status
kubectl get pvc -n <NAMESPACE>

# Check PV status
kubectl get pv

# Check StorageClasses
kubectl get storageclass

# Check CSI driver pods
kubectl get pods -n kube-system | grep csi
```

## PVC Lifecycle

### PVC States

| State | Meaning |
|-------|---------|
| Pending | Waiting for PV binding or provisioning |
| Bound | Successfully bound to PV |
| Lost | PV exists but is unavailable |

### PVC Investigation

```bash
# Get PVC details
kubectl describe pvc <PVC_NAME> -n <NAMESPACE>

# Check PVC status
kubectl get pvc <PVC_NAME> -n <NAMESPACE> -o jsonpath='{.status.phase}'

# Check PVC events
kubectl get events -n <NAMESPACE> --field-selector involvedObject.name=<PVC_NAME>

# Check PVC spec
kubectl get pvc <PVC_NAME> -n <NAMESPACE> -o yaml
```

### Common PVC Issues

**Pending PVC**:
```bash
# 1. Check if StorageClass exists
kubectl get storageclass <STORAGE_CLASS_NAME>

# 2. Check StorageClass is default (if not specified)
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'

# 3. Check PV availability (for static provisioning)
kubectl get pv | grep Available

# 4. Check PVC size matches available PV
kubectl get pvc <PVC_NAME> -n <NAMESPACE> -o jsonpath='{.spec.resources.requests.storage}'
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase
```

## PV and PVC Binding

### Binding Requirements

For PVC to bind to PV, all must match:
1. **Size**: PV capacity ≥ PVC request
2. **Access Mode**: PV supports PVC's access mode
3. **StorageClass**: PV's storageClassName matches PVC's
4. **Selector**: PVC selector matches PV labels (if specified)

### Access Modes

| Mode | Abbreviation | Description |
|------|--------------|-------------|
| ReadWriteOnce | RWO | Single node read-write |
| ReadOnlyMany | ROX | Multiple nodes read-only |
| ReadWriteMany | RWX | Multiple nodes read-write |
| ReadWriteOncePod | RWOP | Single pod read-write (1.22+) |

```bash
# Check PVC access mode
kubectl get pvc <PVC_NAME> -n <NAMESPACE> -o jsonpath='{.spec.accessModes}'

# Check PV access modes
kubectl get pv <PV_NAME> -o jsonpath='{.spec.accessModes}'
```

### Binding Investigation

```bash
# Check if PVC is bound
kubectl get pvc <PVC_NAME> -n <NAMESPACE> -o jsonpath='{.spec.volumeName}'

# Check PV claim reference
kubectl get pv <PV_NAME> -o jsonpath='{.spec.claimRef}'

# List unbound PVs
kubectl get pv | grep Available

# Check binding mode
kubectl get storageclass <SC_NAME> -o jsonpath='{.volumeBindingMode}'
```

### Volume Binding Modes

**Immediate** (default):
- PV provisioned immediately when PVC created
- May cause pod scheduling issues if PV in wrong zone

**WaitForFirstConsumer**:
- PV provisioned when pod using PVC is scheduled
- Ensures PV created in correct zone for pod

## StorageClass Troubleshooting

### StorageClass Investigation

```bash
# List all StorageClasses
kubectl get storageclass

# Get default StorageClass
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'

# Describe StorageClass
kubectl describe storageclass <SC_NAME>

# Check StorageClass parameters
kubectl get storageclass <SC_NAME> -o jsonpath='{.parameters}'

# Check provisioner
kubectl get storageclass <SC_NAME> -o jsonpath='{.provisioner}'
```

### Common StorageClass Issues

**No default StorageClass**:
```bash
# Set default StorageClass
kubectl patch storageclass <SC_NAME> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**Wrong provisioner**:
```bash
# Verify provisioner pods are running
kubectl get pods -n kube-system | grep <PROVISIONER_NAME>

# Check provisioner logs
kubectl logs -n kube-system <PROVISIONER_POD>
```

**Invalid parameters**:
```bash
# Check StorageClass parameters
kubectl get storageclass <SC_NAME> -o yaml

# Verify parameters are supported by CSI driver
kubectl describe csidriver <DRIVER_NAME>
```

## CSI Driver Issues

### CSI Architecture

**Components**:
1. **Controller Plugin**: Handles volume provisioning, attachment, snapshots
2. **Node Plugin**: Handles volume mounting on nodes
3. **Driver Registrar**: Registers CSI driver with kubelet

### CSI Driver Investigation

```bash
# List CSI drivers
kubectl get csidrivers

# Describe CSI driver
kubectl describe csidriver <DRIVER_NAME>

# Check CSI controller pods
kubectl get pods -n kube-system -l app=<DRIVER>-controller

# Check CSI node pods (DaemonSet)
kubectl get pods -n kube-system -l app=<DRIVER>-node

# Check specific node's CSI pod
kubectl get pods -n kube-system --field-selector spec.nodeName=<NODE_NAME> | grep csi
```

### CSI Controller Logs

```bash
# Get controller pod name
CONTROLLER_POD=$(kubectl get pods -n kube-system -l app=<DRIVER>-controller -o jsonpath='{.items[0].metadata.name}')

# Check provisioner container
kubectl logs -n kube-system $CONTROLLER_POD -c csi-provisioner --tail=100

# Check attacher container
kubectl logs -n kube-system $CONTROLLER_POD -c csi-attacher --tail=100

# Check snapshotter container (if exists)
kubectl logs -n kube-system $CONTROLLER_POD -c csi-snapshotter --tail=100

# Check driver container
kubectl logs -n kube-system $CONTROLLER_POD -c <DRIVER-NAME> --tail=100
```

### CSI Node Logs

```bash
# Get node plugin pod
NODE_POD=$(kubectl get pods -n kube-system -l app=<DRIVER>-node --field-selector spec.nodeName=<NODE_NAME> -o jsonpath='{.items[0].metadata.name}')

# Check node driver registrar
kubectl logs -n kube-system $NODE_POD -c node-driver-registrar --tail=100

# Check driver container
kubectl logs -n kube-system $NODE_POD -c <DRIVER-NAME> --tail=100
```

### Common CSI Issues

**CSI driver not installed**:
```bash
# Check if CSI driver is installed
kubectl get csidrivers
kubectl get pods -n kube-system | grep csi

# Check installation (Helm example)
helm list -n kube-system | grep <DRIVER>
```

**CSI driver not registered on node**:
```bash
# Check CSI driver registration
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host ls -la /var/lib/kubelet/plugins_registry/

# Check kubelet plugin directory
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host ls -la /var/lib/kubelet/plugins/
```

**CSI driver version mismatch**:
```bash
# Check controller version
kubectl get deployment -n kube-system <DRIVER>-controller -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check node DaemonSet version
kubectl get daemonset -n kube-system <DRIVER>-node -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Volume Attachment Problems

### VolumeAttachment Investigation

```bash
# List all volume attachments
kubectl get volumeattachments

# Describe specific attachment
kubectl describe volumeattachment <ATTACHMENT_NAME>

# Check attachment status
kubectl get volumeattachment <ATTACHMENT_NAME> -o jsonpath='{.status.attached}'

# Find attachments for specific PV
kubectl get volumeattachments -o json | jq '.items[] | select(.spec.source.persistentVolumeName=="<PV_NAME>")'

# Find attachments on specific node
kubectl get volumeattachments -o json | jq '.items[] | select(.spec.nodeName=="<NODE_NAME>")'
```

### Attachment Errors

```bash
# Check attachment errors
kubectl get volumeattachment <ATTACHMENT_NAME> -o jsonpath='{.status.attachError}'

# Check detachment errors
kubectl get volumeattachment <ATTACHMENT_NAME> -o jsonpath='{.status.detachError}'

# Check events
kubectl get events --all-namespaces --field-selector involvedObject.kind=VolumeAttachment
```

### Common Attachment Issues

**Volume stuck attaching**:
```bash
# Check CSI attacher logs
kubectl logs -n kube-system -l app=<DRIVER>-controller -c csi-attacher --tail=50

# Check if volume already attached to another node
kubectl get volumeattachments -o wide

# Check cloud provider attachment limits (AWS EBS example: 39 volumes per instance)
kubectl describe node <NODE_NAME> | grep -A 5 "Attachable Volumes"
```

**Volume stuck detaching**:
```bash
# Check if pod is still using volume
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName=="<PVC_NAME>") | .metadata.name'

# Force delete pod if stuck
kubectl delete pod <POD_NAME> -n <NAMESPACE> --grace-period=0 --force

# Check finalizers on PVC
kubectl get pvc <PVC_NAME> -n <NAMESPACE> -o jsonpath='{.metadata.finalizers}'
```

## Mount Failures

### Mount Investigation

```bash
# Check pod mount status
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 10 "Volumes"

# Check mount events
kubectl get events -n <NAMESPACE> --field-selector involvedObject.name=<POD_NAME> | grep -i mount

# Check kubelet logs for mount errors (requires node access)
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host journalctl -u kubelet | grep -i mount | tail -50
```

### Common Mount Errors

**FailedMount: MountVolume.SetUp failed**:
```bash
# Check CSI node driver logs
kubectl logs -n kube-system -l app=<DRIVER>-node --field-selector spec.nodeName=<NODE_NAME> --tail=50

# Check volume is attached
kubectl get volumeattachments | grep <PV_NAME>

# Check device path on node
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host lsblk
```

**FailedMount: Volume not attached**:
```bash
# Check if attachment succeeded
kubectl get volumeattachments -o wide

# Check CSI attacher logs
kubectl logs -n kube-system -l app=<DRIVER>-controller -c csi-attacher --tail=100
```

**FailedMount: Wrong fstype**:
```bash
# Check PV fstype
kubectl get pv <PV_NAME> -o jsonpath='{.spec.csi.fsType}'

# Check volume format on node
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host file -s /dev/disk/by-id/<VOLUME_ID>
```

**FailedMount: Permission denied**:
```bash
# Check pod security context
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.securityContext}'

# Check volume access modes
kubectl get pv <PV_NAME> -o jsonpath='{.spec.accessModes}'

# Check mount options
kubectl get pv <PV_NAME> -o jsonpath='{.spec.mountOptions}'
```

## Cloud Provider Specifics

### AWS EBS

**Common Issues**:

**Volume in different AZ than node**:
```bash
# Check PV zone
kubectl get pv <PV_NAME> -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}'

# Check pod node zone
NODE_NAME=$(kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.nodeName}')
kubectl get node $NODE_NAME -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}'

# Use WaitForFirstConsumer binding mode to prevent this
kubectl get storageclass <SC_NAME> -o jsonpath='{.volumeBindingMode}'
```

**EBS volume attachment limit reached**:
```bash
# Check attached volumes on node
kubectl describe node <NODE_NAME> | grep -A 5 "Attachable Volumes"

# List volume attachments for node
kubectl get volumeattachments -o json | \
  jq -r '.items[] | select(.spec.nodeName=="<NODE_NAME>") | .spec.source.persistentVolumeName'
```

**EBS CSI driver logs**:
```bash
# Controller logs
kubectl logs -n kube-system -l app=ebs-csi-controller -c ebs-plugin --tail=100

# Node logs
kubectl logs -n kube-system -l app=ebs-csi-node -c ebs-plugin --tail=100
```

### Azure Disk

**Common Issues**:

**Disk already attached to another VM**:
```bash
# Check volume attachments
kubectl get volumeattachments -o json | \
  jq '.items[] | select(.spec.source.persistentVolumeName=="<PV_NAME>")'

# Check Azure disk state in events
kubectl get events --all-namespaces | grep <PV_NAME>
```

**Premium disk on Standard VM**:
```bash
# Check StorageClass SKU
kubectl get storageclass <SC_NAME> -o jsonpath='{.parameters.skuName}'

# Check node VM size (requires Azure CLI)
# az vm show --resource-group <RG> --name <VM_NAME> --query hardwareProfile.vmSize
```

**Azure Disk CSI driver logs**:
```bash
# Controller logs
kubectl logs -n kube-system -l app=csi-azuredisk-controller -c azuredisk --tail=100

# Node logs
kubectl logs -n kube-system -l app=csi-azuredisk-node -c azuredisk --tail=100
```

### GCE Persistent Disk

**Common Issues**:

**Disk in different zone than node**:
```bash
# Check PV zone
kubectl get pv <PV_NAME> -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values}'

# Check pod node zone
NODE_NAME=$(kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.nodeName}')
kubectl get node $NODE_NAME -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}'
```

**GCE PD attachment limit**:
```bash
# Check attachable volumes limit
kubectl describe node <NODE_NAME> | grep "Attachable Volumes"

# List attached volumes
kubectl get volumeattachments -o json | \
  jq -r '.items[] | select(.spec.nodeName=="<NODE_NAME>") | .metadata.name'
```

**GCE PD CSI driver logs**:
```bash
# Controller logs
kubectl logs -n kube-system -l app=gcp-compute-persistent-disk-csi-driver -c gce-pd-driver --tail=100
```

## Performance Issues

### Performance Investigation

```bash
# Check I/O metrics (requires metrics-server)
kubectl top nodes
kubectl top pods -n <NAMESPACE>

# Check volume usage
kubectl exec <POD_NAME> -n <NAMESPACE> -- df -h

# Test volume performance (inside pod)
kubectl exec <POD_NAME> -n <NAMESPACE> -- dd if=/dev/zero of=/mnt/volume/test bs=1M count=1000 oflag=direct
```

### Performance Tuning

**Mount Options**:
```yaml
# StorageClass with mount options
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
mountOptions:
  - noatime
  - nodiratime
```

**Check current mount options**:
```bash
# From node
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host mount | grep <VOLUME_ID>

# From pod
kubectl exec <POD_NAME> -n <NAMESPACE> -- mount | grep /mnt/volume
```

### Volume Metrics

```bash
# Check volume metrics (if supported by CSI driver)
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/<NAMESPACE>/pods/<POD_NAME>" | \
  jq '.containers[].usage'

# Check node volume usage
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes/<NODE_NAME>" | jq
```

## Advanced Troubleshooting

### Volume Snapshots

```bash
# List volume snapshots
kubectl get volumesnapshot -n <NAMESPACE>

# Describe snapshot
kubectl describe volumesnapshot <SNAPSHOT_NAME> -n <NAMESPACE>

# Check snapshot class
kubectl get volumesnapshotclass

# Check snapshot events
kubectl get events -n <NAMESPACE> --field-selector involvedObject.kind=VolumeSnapshot
```

### Volume Cloning

```bash
# Check if cloning is supported
kubectl get csidriver <DRIVER_NAME> -o jsonpath='{.spec.volumeLifecycleModes}'

# Check clone PVC
kubectl describe pvc <CLONED_PVC_NAME> -n <NAMESPACE>
```

### Volume Expansion

```bash
# Check if expansion is supported
kubectl get storageclass <SC_NAME> -o jsonpath='{.allowVolumeExpansion}'

# Check PVC expansion status
kubectl get pvc <PVC_NAME> -n <NAMESPACE> -o jsonpath='{.status.conditions[?(@.type=="FileSystemResizePending")]}'

# Trigger expansion (requires pod restart)
kubectl patch pvc <PVC_NAME> -n <NAMESPACE> -p '{"spec":{"resources":{"requests":{"storage":"<NEW_SIZE>"}}}}'
```

### Finalizers and Cleanup

```bash
# Check PVC finalizers
kubectl get pvc <PVC_NAME> -n <NAMESPACE> -o jsonpath='{.metadata.finalizers}'

# Check PV finalizers
kubectl get pv <PV_NAME> -o jsonpath='{.metadata.finalizers}'

# Remove finalizer (use with caution!)
kubectl patch pvc <PVC_NAME> -n <NAMESPACE> -p '{"metadata":{"finalizers":null}}' --type=merge
```

## Best Practices

1. **Use WaitForFirstConsumer binding mode** - Ensures volume in correct zone
2. **Set appropriate resource requests** - Match volume size to actual needs
3. **Monitor volume usage** - Avoid full volumes
4. **Use volume snapshots** - For backup and recovery
5. **Test volume performance** - Verify IOPS and throughput
6. **Check CSI driver compatibility** - Ensure driver supports required features
7. **Use StorageClass parameters** - Optimize for workload requirements
8. **Monitor attachment limits** - Cloud providers have per-node limits
9. **Clean up unused PVs** - Reduce costs and complexity
10. **Use persistent volume reclaim policies correctly** - Delete vs Retain

## Debugging Checklist

When troubleshooting storage issues, check in order:

1. ✓ PVC exists and status
2. ✓ StorageClass exists and is correct
3. ✓ CSI driver pods running
4. ✓ PV provisioned and bound
5. ✓ Volume attached to node
6. ✓ Volume mounted in pod
7. ✓ Filesystem accessible from pod
8. ✓ Permissions correct
9. ✓ Performance acceptable
10. ✓ No errors in events or logs
