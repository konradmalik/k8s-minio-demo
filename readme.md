# Distributed Workstations

This is a working demo of Minio deployemnt on Kubernetes `k3s` through a local `k3d` cluster in docker.
Minio is deployed using a Minio-operator for Kubernetes.

## Control plane

K3s satisfies all the below requirements:

- Lightweight Kubernetes distribution
- version 1.19.x (>= 1.17)
- support for `helm`
- support for local node storage (default storage class)
- easy tests/development using `k3d`

## Tools needed

- `k3d`
- `kubectl`
- `krew`
- `helm`
- `make`

## Prerequisites

Fulfill using the supplied `Makefile`

- deploy k3d:

```
$ make k3d-create
```

To tear down the cluster and remove any leftovers just delete this k3d cluster:

```
$ make k3d-delete
```

## Storage

- minio deployed through the operator and installed via `krew`
- **supported minio krew version is v4.0.2**!
- supports extending existing deployments
- supports multiple tenants (ex. 1 tenant for images, 2 for something else)
- minio supports serving as a backend for S3, Azure or Google blob storages
- supports S3 api
- provides libraries for programmatic access

### Capacity

Total space is simply the number of data disks \* space per disk.
Minio starts with default configuration of N/2 data and N/2 parity disks.
So in default configuration, say you have 8 disks of 1 TiB each,
then total usable space is

```
Number of data disks [4] * Space per disk [1 TiB] = 4 TiB.
```

Why equal disks are needed?
See this capacity checks:

- 6+6+6+6 GB = 12 GB => N/2
- 6+8+10+12 GB = 12 GB => 33%
- 14+12+15+10 GB = 20 GB => 39%

Redundancy can be configured, but obviously do this with utmost care.
Info here: https://github.com/minio/minio/tree/master/docs/config#storage-class

### Availabilty requirements and guidance

- A distributed MinIO setup with m servers and n disks will have your data safe as long as m/2 servers or m\*n/2 or more disks are online.
- MinIO creates erasure-coding sets of 4 to 16 drives per set. The number of drives you provide in total must be a multiple of one of those numbers.

### Steps

- make sure minio operator is installed

```
$ make krew-install-minio
```

You may need to modify your `PATH`, follow the hints from `krew`.

- create a new tenant
  - make sure to review the yaml file and adjust servers, volumes, capacity etc. accordingly
  - make sure to review "Availabilty requirements and guidance" above as it is **VERY** important which numbers are provided during production deployment
- in short, seems like we need:
  - no more minio servers than nodes in the cluster
  - minimum 4 drives in total per minio cluster, always keep the multiple of any number between 4 and 16
  - same number of drives and server resources per minio server
  - at minimum 1 server. **The cluster must have at least one available worker Node per minio pod**.

```
$ make minio-create
```

The above command deploys:

- minio servers
- 1 minio console (web app)
- minio operator dashboard

For applications external to the Kubernetes cluster, you must configure Ingress or a Load Balancer to expose the MinIO Tenant services. Alternatively, you can use the kubectl port-forward command to temporarily forward traffic from the local host to the MinIO Tenant (see Access section).

- The minio service provides access to MinIO Object Storage operations.
- The minio-tenant-1-console service provides access to the MinIO Console. The MinIO Console supports GUI administration of the MinIO Tenant.
- The minio-operator service provides access to the MinIO Operator dashboard - helps to manage multiple tenants/clusters.

#### TLS note

MinIO Tenants deploy with TLS enabled by default, where the MinIO Operator uses the Kubernetes certificates.k8s.io API to generate the required x.509 certificates. Each certificate is signed using the Kubernetes Certificate Authority (CA) configured during cluster deployment. While Kubernetes mounts this CA on Pods in the cluster, Pods do not trust that CA by default. You must copy the CA to a directory such that the update-ca-certificates utility can find and add it to the system trust store to enable validation of MinIO TLS certificates:

```
$ cp /var/run/secrets/kubernetes.io/serviceaccount/ca.crt /usr/local/share/ca-certificates/
$ update-ca-certificates
```

Above only concerns "trust". All operations can still be performed by adding tool-specific flags like `--insecure` for `curl`, `mc` etc.

### Expanding

**NOTE:**

- During Tenant expansion, MinIO Operator removes the existing StatefulSet and creates a new StatefulSet with required number of Pods. This means, there is a downtime during expansion, as the pods are terminated and created again. As existing StatefulSet pods are terminated, its PVCs are also deleted. It is very important to ensure PVs bound to MinIO StatefulSet PVCs are not deleted at this time to avoid data loss. We recommend configuring every PV with reclaim policy retain, to ensure the PV is not deleted. If you attempt Tenant expansion while the PV reclaim policy is set to something else, it may lead to data loss. If you have the reclaim policy set to something else, change it as explained in Kubernetes documents.
- MinIO server currently doesn't support reducing storage capacity.
  Expanding minio clusters is easy:
  The following kubectl minio command expands a MinIO Tenant with an additional 2 minio pods, 2 volumes, and added capacity of 2Gi:

```
kubectl minio tenant expand minio-tenant \
	--namespace minio-tenant \
	--servers 2 \
	--volumes 2 \
	--capacity 2Gi
```

### Access

As mentioned earlier, appropriate services for access need to be created manually.
Existing services can be accessed for admin/debug/demo as follows:

```
$ # main cluster access point
$ make minio-server-port-forward
$ # console (web interface)
$ make minio-console-port-forward
$ # operator UI (web interface for cluster management)
$ make minio-operator-port-forward
```

The main service providing all operations is `minio` on 443.

Console access keys allow to login to the GUI as console admin, add users, set permissions etc.
They also allow for programmatic access - these are your main credentials for everything.

Access and secret keys (not console) are for admin access to the whole cluster via `mc` command.

### Updates

- use mc command to update all servers in the cluster (this can even be done from a private mirror when no internet is available)

```
$ mc admin update <alias>
```

- this is done so that any migration that is needed is performed
- note the version that we updated to
- change the version of the image in the deployment yaml to the one we updated to
- reapply the deployment yaml (this should restart all minio servers, downtime will occur but restart is advised)
  We **do not** restart manually:
  `$ mc service restart <alias>`
  because the yaml-reapply method ensures that kubernetes reflects the actual state of our application which is vital.

### Examples

#### Python upload

- set up and activate virtual env using provided `Makefile` (ex. `make venv && source venv/bin/activate`)
- make sure minio is accessible (run `minio-server-port-forward`)
- run the example (notice disabled certificate check, what file we are uploading and where)

#### mc client

- run pod with `mc` using `make minio-mc` (notice env variables that allow to automatically setup connectivity and namespace that allows direct dns lookup)
- first use will prepopulate local configuration, ex. list all buckets: `mc ls demo --insecure` (keep insecure flag because we have self-signed certificate)
- test commands, see the uploaded file etc.

### Certificates

In this demo we generate (minio operator + kubernetes) a self-signed certificate. If a proper certificate is required, there are a couple of possibilities:

- provide your custom certificate through "externalCerts" config in minio.yaml (see official docs)
- use stuff like kubernetes cert manager with let's encrypt
