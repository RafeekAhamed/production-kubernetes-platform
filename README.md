# Production Kubernetes Platform

A hands-on DevOps project that packages a Flask application, connects it
to PostgreSQL, deploys it to Kubernetes with Helm, automates image
builds with GitHub Actions, and adds Prometheus/Grafana monitoring.

> **Environment:** Local Kubernetes on Docker Desktop. This project does
> not require an AWS or Azure cluster.

## Project Goals

-   Build and test a small containerized backend.
-   Run application and database workloads in Kubernetes.
-   Use Kubernetes probes, resource requests/limits, and container
    security controls.
-   Manage application deployment with Helm.
-   Build and publish Docker images through GitHub Actions.
-   Monitor Kubernetes and monitoring-stack health with Prometheus and
    Grafana.

## Technology Stack

  Area                      Tools
  ------------------------- --------------------------------------------------------
  Application               Python, Flask, Gunicorn
  Database                  PostgreSQL
  Containers                Docker
  Orchestration             Kubernetes, kubectl
  Packaging and release     Helm
  CI and image publishing   GitHub Actions, Docker Hub
  Monitoring                Prometheus, Grafana, kube-state-metrics, Node Exporter
  Automation                PowerShell

## Architecture

``` text
Developer
   |
   v
GitHub repository
   |
   +--> GitHub Actions --> Run Python tests --> Build image --> Push to Docker Hub
   |
   v
Docker Desktop Kubernetes
   |
   +--> Namespace: production-platform
   |      |
   |      +--> Flask backend Deployment
   |      +--> Backend Service
   |      +--> PostgreSQL Deployment
   |      +--> PostgreSQL Service
   |      +--> PersistentVolumeClaim
   |      +--> Kubernetes Secret (database credentials)
   |
   +--> Namespace: monitoring
          |
          +--> Prometheus
          +--> Grafana
          +--> kube-state-metrics
          +--> Node Exporter
          +--> Prometheus Operator
```

The monitoring stack currently collects metrics from Prometheus and
several Kubernetes targets. Application-specific dashboards and Flask
request metrics are not yet documented as complete features.

## Repository Structure

``` text
production-kubernetes-platform/
├── backend/
│   ├── app.py
│   ├── Dockerfile
│   └── ...
├── k8s/
│   ├── ...
│   └── postgres-secret.yaml       # local secret manifest; do not commit
├── helm/
│   └── production-platform/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── monitoring/
│   ├── values.yaml
│   └── kube-prometheus-stack/     # locally pulled Helm chart; do not commit rendered output
├── scripts/
│   └── deploy.ps1
├── .github/
│   └── workflows/
├── .gitignore
└── README.md
```

Some chart or manifest filenames may differ as the project evolves. Keep
generated files, local credentials, and rendered monitoring manifests
out of Git.

## Application Endpoints

The Flask backend exposes these endpoints:

  Endpoint       Purpose
  -------------- --------------------------------
  `/`            Basic application response
  `/health`      Liveness/health check
  `/ready`       Readiness check
  `/info`        Application information
  `/db-health`   Checks PostgreSQL connectivity

The `/db-health` endpoint has been tested against the PostgreSQL
database in the local Kubernetes environment.

## Prerequisites

Install and verify the following tools:

-   Git
-   Docker Desktop with Kubernetes enabled
-   `kubectl`
-   Helm
-   Python 3.12 or a compatible Python version
-   A Docker Hub account for image publishing

Check the Kubernetes context before applying resources:

``` powershell
kubectl config current-context
kubectl get nodes
```

The expected local context in the current setup is `docker-desktop`.
Confirm it before running deployment commands.

## Run Tests Locally

From the repository root, create and activate a Python virtual
environment if the project uses one:

``` powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Install the backend requirements file if present, then run the tests:

``` powershell
python -m pip install -r .\backend\requirements.txt
python -m unittest discover -s .\backend -p "test*.py" -v
```

Adjust the requirements or test command if the filenames in your
checkout differ. The current project test suite previously passed **6
tests**.

## Build and Run the Container

Build the backend image from the repository root:

``` powershell
docker build -t production-kubernetes-platform:local .\backend
```

Run it locally only when the image's required environment variables and
database configuration are supplied. For the full database-backed setup,
deploy through Kubernetes so the application can use the in-cluster
PostgreSQL Service.

## Kubernetes Deployment

The application namespace used by the current deployment is
`production-platform`.

Inspect resources:

``` powershell
kubectl get all -n production-platform
kubectl get pvc -n production-platform
kubectl get secrets -n production-platform
```

Do not print or commit Secret values. The PostgreSQL credentials are
stored in a Kubernetes Secret; the local secret manifest is excluded
from version control.

### Deploy with Helm

The Helm chart is located at `helm/production-platform`.

Inspect the chart:

``` powershell
helm lint .\helm\production-platform
helm template production-platform .\helm\production-platform -n production-platform
```

The project includes a deployment helper:

``` powershell
.\scripts\deploy.ps1
```

Review the script before executing it and confirm the Docker Desktop
Kubernetes context is selected. The script performs a Helm upgrade,
waits for rollout, and runs local health checks using port-forwarding.

Check the release and workloads:

``` powershell
helm list -n production-platform
kubectl rollout status deployment -n production-platform
kubectl get pods,svc,pvc -n production-platform
```

### Database Persistence

PostgreSQL uses a PersistentVolumeClaim. Persistence across a PostgreSQL
Pod restart has been verified in the local environment. This is **not**
a backup, disaster-recovery, or production high-availability strategy.

## Container and Kubernetes Security

The backend container and Kubernetes deployment are configured with
hardening measures, including:

-   Non-root execution (UID/GID `10001`)
-   `RuntimeDefault` seccomp profile
-   Privilege escalation disabled
-   Read-only root filesystem
-   All Linux capabilities dropped
-   Writable temporary directory mounted separately
-   CPU and memory requests/limits
-   Startup, liveness, and readiness probes

Review the current manifests and Helm values to confirm the effective
configuration after changes.

## CI/CD and Image Publishing

The GitHub Actions workflow runs the Python tests, builds the Docker
image, and publishes image tags to Docker Hub on pushes to the
configured branch.

The workflow uses GitHub repository secrets:

-   `DOCKERHUB_USERNAME`
-   `DOCKERHUB_TOKEN`

Create these secrets in the repository settings; never store credentials
in workflow YAML or commit them to Git. The current image repository is:

``` text
rafeekahamed/production-kubernetes-platform
```

The pipeline publishes `latest` and a commit-SHA tag. Kubernetes
deployment is currently triggered through the deployment script; do not
assume the GitHub Actions workflow automatically deploys to the cluster.

## Prometheus and Grafana Monitoring

The `monitoring` namespace contains a Helm-installed
`kube-prometheus-stack` with Prometheus, Grafana, Prometheus Operator,
kube-state-metrics, and Node Exporter.

Check component status:

``` powershell
kubectl get pods -n monitoring
helm status monitoring -n monitoring
```

### Access Grafana

In a dedicated PowerShell window, run:

``` powershell
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Keep the command running and open:

``` text
http://localhost:3000
```

Log in using the configured Grafana administrator credentials. The
password is stored in the `grafana-admin` Kubernetes Secret. Do not put
the password in this README or commit it to source control.

### Access Prometheus

If local port `9090` is already occupied, use `9091`:

``` powershell
kubectl port-forward -n monitoring svc/monitoring-prometheus 9091:9090
```

Keep the command running and open:

``` text
http://localhost:9091
```

Run this PromQL query:

``` promql
up
```

A value of `1` means a target scrape succeeded; `0` means the target was
discovered but its scrape failed. In the current Docker Desktop
environment, Prometheus, Grafana, the API server, kubelet, CoreDNS, and
kube-state-metrics were observed reporting `1`. Some control-plane
targets (including etcd, controller-manager, scheduler, and kube-proxy)
reported `0`; inspect each target's **Last scrape error** at `/targets`
before deciding whether a configuration change is appropriate. The Node
Exporter result should also be verified rather than assumed healthy.

### Monitoring Limitations

-   Monitoring data uses ephemeral storage in the current configuration;
    it is not guaranteed to survive Pod recreation.
-   Prometheus target status can vary by local Kubernetes distribution.
-   Flask-specific request metrics and a dedicated application
    ServiceMonitor/dashboard still need to be configured and verified.
-   No production alert delivery or long-term metrics retention is
    claimed by this setup.

## Troubleshooting

### Port-forward says the local port is already in use

An existing port-forward may still be running. Reuse it, stop the old
process with `Ctrl+C` in its terminal, or choose another local port.

For example:

``` powershell
kubectl port-forward -n monitoring svc/monitoring-prometheus 9091:9090
```

### A Pod is not ready

``` powershell
kubectl get pods -n production-platform
kubectl describe pod <pod-name> -n production-platform
kubectl logs <pod-name> -n production-platform
```

Replace `<pod-name>` with the actual Pod name. Inspect events and
container logs before changing resources.

### Prometheus target is down

Open `http://localhost:9091/targets` while the Prometheus port-forward
is running. Inspect the target's last scrape error. Do not disable
monitoring targets merely to make the dashboard green; determine whether
the target is expected to be scrapeable in the local cluster.

## Safe Repository Practices

Before committing, review the working tree and ignored files:

``` powershell
git status --short
git check-ignore .\k8s\postgres-secret.yaml
```

Never commit:

-   Kubernetes Secret manifests containing real credentials
-   `.env` files or tokens
-   Docker Hub access tokens
-   Generated rendered monitoring manifests
-   Local virtual environments or build artifacts

Rotate any credential that has accidentally been committed or exposed.

## Current Status

  -----------------------------------------------------------------------
  Area                                Status
  ----------------------------------- -----------------------------------
  Flask backend and health endpoints  Implemented

  Automated backend tests             6 tests previously passed

  Docker image build and Docker Hub   Implemented through GitHub Actions
  publishing                          

  Kubernetes backend and PostgreSQL   Implemented in local cluster
  deployment                          

  PostgreSQL PVC                      Restart persistence verified
                                      locally

  Helm application chart              Implemented

  PowerShell deployment helper        Implemented

  Prometheus and Grafana stack        Installed and running locally

  Kubernetes target monitoring        Partially verified; some local
                                      control-plane targets report down

  Flask application metrics and       Remaining work
  dedicated dashboard                 

  Persistent monitoring storage,      Not configured/verified as
  backups, and alert delivery         production capabilities
  -----------------------------------------------------------------------

## Future Improvements

-   Expose and scrape Flask application metrics.
-   Create a dedicated application dashboard in Grafana.
-   Add and verify actionable alert rules.
-   Decide on persistent storage and metrics retention requirements.
-   Add repeatable end-to-end deployment validation.
-   Document backup and recovery procedures before treating the database
    as production-ready.

## Author

**Rafeek Ahamed M.**

-   GitHub: https://github.com/RafeekAhamed
-   LinkedIn: https://linkedin.com/in/rafeek-ahamed-devops
-   Docker Hub:
    https://hub.docker.com/r/rafeekahamed/production-kubernetes-platform
