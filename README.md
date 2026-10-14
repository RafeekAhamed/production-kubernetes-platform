\# Production Kubernetes Platform



A hands-on DevOps portfolio project demonstrating containerized application deployment, Kubernetes orchestration, PostgreSQL integration, persistent storage, Helm-based deployments, automated testing, and CI workflows.



\## Project Overview



This project deploys a Python Flask backend on Kubernetes and integrates it with PostgreSQL. It demonstrates practical implementation of application health checks, container security, resource management, persistent volumes, and deployment automation.



\## Technology Stack



\* \*\*Application:\*\* Python, Flask, Gunicorn

\* \*\*Containerization:\*\* Docker

\* \*\*Orchestration:\*\* Kubernetes

\* \*\*Database:\*\* PostgreSQL

\* \*\*Package Management:\*\* Helm

\* \*\*CI:\*\* GitHub Actions

\* \*\*Testing:\*\* Python `unittest`

\* \*\*Monitoring:\*\* Prometheus and Grafana — planned integration



\## Architecture



```text

&#x20;                   Developer

&#x20;                       |

&#x20;                       v

&#x20;                 GitHub Repository

&#x20;                       |

&#x20;                       v

&#x20;                GitHub Actions CI

&#x20;                /              \\

&#x20;               v                v

&#x20;        Automated Tests    Docker Build

&#x20;                                 |

&#x20;                                 v

&#x20;                        Backend Container

&#x20;                                 |

&#x20;                                 v

&#x20;                        Kubernetes Service

&#x20;                                 |

&#x20;                                 v

&#x20;                        Flask Backend Pods

&#x20;                                 |

&#x20;                                 v

&#x20;                          PostgreSQL

&#x20;                                 |

&#x20;                                 v

&#x20;                      Persistent Volume Claim

```



The backend runs in Kubernetes and connects to PostgreSQL through an internal Kubernetes Service. A PersistentVolumeClaim provides storage for PostgreSQL data.



\## Key Features



\### Application



\* Flask REST endpoints for application status and database connectivity.

\* Gunicorn as the production-oriented WSGI server.

\* PostgreSQL connectivity using Psycopg.

\* Automated unit tests for application endpoints and database connection scenarios.



\### Docker



\* Containerized Python backend.

\* Non-root application user.

\* Dependency installation from a requirements file.

\* Container image build validation.



\### Kubernetes



\* Dedicated `production-platform` namespace.

\* Backend Deployment with multiple replicas.

\* Kubernetes Service for backend access.

\* PostgreSQL Deployment and internal Service.

\* PersistentVolumeClaim for database storage.

\* Startup, liveness, and readiness probes.

\* CPU and memory resource requests and limits.

\* Container security settings, including a read-only root filesystem and dropped Linux capabilities.



\### Database



\* PostgreSQL integration with the Flask backend.

\* Kubernetes Secret references for database credentials.

\* Database health-check endpoint.

\* Persistent storage validation across PostgreSQL Pod recreation.



\### Helm



\* Helm chart under `helm/production-platform`.

\* Configurable chart values.

\* Kubernetes templates for the backend Deployment and Service.

\* Configuration for container security, resources, probes, and database connectivity.



\### Continuous Integration



The GitHub Actions workflow in `.github/workflows/ci.yml` is configured to:



1\. Check out the repository.

2\. Set up Python 3.12.

3\. Install backend dependencies.

4\. Run automated tests.

5\. Build the Docker image without publishing it.



\## Project Structure



```text

production-kubernetes-platform/

├── .github/

│   └── workflows/

│       └── ci.yml

├── backend/

│   ├── app.py

│   ├── Dockerfile

│   └── requirements.txt

├── helm/

│   └── production-platform/

│       ├── Chart.yaml

│       ├── values.yaml

│       └── templates/

│           ├── \_helpers.tpl

│           ├── backend-deployment.yaml

│           └── backend-service.yaml

├── k8s/

│   ├── namespace.yaml

│   ├── backend-deployment.yaml

│   ├── backend-service.yaml

│   ├── postgres-deployment.yaml

│   ├── postgres-pvc.yaml

│   └── postgres-service.yaml

├── tests/

│   └── test\_app.py

├── .dockerignore

├── .gitignore

└── README.md

```



The local `k8s/postgres-secret.yaml` file is intentionally excluded from Git because it contains environment-specific credentials.



\## Prerequisites



Install and configure the following tools:



\* Git

\* Python 3.12 or compatible local Python version

\* Docker Desktop

\* Kubernetes enabled in Docker Desktop

\* `kubectl`

\* Helm



Verify the tools:



```powershell

git --version

python --version

docker version

kubectl version --client

helm version

```



\## Run Automated Tests



From the project root, activate your Python virtual environment and install the dependencies:



```powershell

.\\.venv\\Scripts\\Activate.ps1

python -m pip install -r backend/requirements.txt

```



Run the test suite:



```powershell

python -m unittest discover -s tests -v

```



The test suite covers application endpoints and simulated database connectivity scenarios.



\## Build the Docker Image



Run the following command from the project root:



```powershell

docker build -t production-kubernetes-platform:local .\\backend

```



Verify that the image exists:



```powershell

docker images production-kubernetes-platform

```



\## Kubernetes Deployment



Make sure Docker Desktop Kubernetes is enabled and your `kubectl` context points to the intended cluster.



Check the active context:



```powershell

kubectl config current-context

kubectl get nodes

```



Create the namespace:



```powershell

kubectl apply -f .\\k8s\\namespace.yaml

```



\*\*Database credentials:\*\* Create the required `postgres-secret` in the `production-platform` namespace before deploying PostgreSQL and the backend. Use a strong local development password. Do not commit real credentials, paste them into issue trackers, or publish them in documentation.



The secret must provide these keys:



\* `POSTGRES\_DB`

\* `POSTGRES\_USER`

\* `POSTGRES\_PASSWORD`



Deploy PostgreSQL resources:



```powershell

kubectl apply -f .\\k8s\\postgres-pvc.yaml

kubectl apply -f .\\k8s\\postgres-service.yaml

kubectl apply -f .\\k8s\\postgres-deployment.yaml

```



Deploy the backend:



```powershell

kubectl apply -f .\\k8s\\backend-service.yaml

kubectl apply -f .\\k8s\\backend-deployment.yaml

```



Check the resources:



```powershell

kubectl get pods -n production-platform

kubectl get services -n production-platform

kubectl get pvc -n production-platform

```



These commands assume that the required database Secret exists and that the image referenced by the Deployment is available to the cluster.



\## Helm Validation



Validate the chart:



```powershell

helm lint .\\helm\\production-platform

helm template production-platform .\\helm\\production-platform

```



Review the rendered Kubernetes resources before installing or upgrading a release.



\## Application Endpoints



| Endpoint     | Purpose                          |

| ------------ | -------------------------------- |

| `/`          | Application information          |

| `/health`    | Application health check         |

| `/ready`     | Readiness check                  |

| `/info`      | Application information endpoint |

| `/db-health` | Database connectivity check      |



The database health endpoint requires a working PostgreSQL connection. When the database is unavailable, the application reports an unsuccessful health result rather than a successful database connection.



\## Security Practices



\* Run the application as a non-root user.

\* Use Kubernetes Secrets for database credentials.

\* Exclude local secrets and virtual environments from version control.

\* Apply container security settings, including a read-only root filesystem where configured.

\* Define Kubernetes resource requests and limits.

\* Use health probes to support Kubernetes health management.

\* Review staged changes before committing code.



Kubernetes Secrets provide configuration separation, but they should not be treated as a complete secrets-management solution by themselves.



\## Validation Status



The following items have been validated during development:



\* Flask backend endpoints and database health checks.

\* Six automated unit tests passing locally.

\* Docker image build.

\* Kubernetes backend and PostgreSQL deployment checks.

\* PostgreSQL connectivity from the backend.

\* Database record persistence across PostgreSQL Pod recreation.

\* Helm chart linting and template rendering.



The GitHub Actions workflow is configured locally; its execution on GitHub must be verified after the repository is pushed.



Prometheus/Grafana integration, image publishing, deployment automation, and final end-to-end validation remain future project tasks.



\## Future Improvements



\* Add Prometheus metrics and Grafana dashboards.

\* Publish versioned Docker images to a container registry.

\* Extend CI with Helm linting and Kubernetes manifest validation.

\* Add automated deployment workflows.

\* Add database backup and restore validation.

\* Improve observability with structured logs and actionable alerts.



\## Project Goal



Demonstrate practical DevOps skills in containerization, Kubernetes operations, application and database integration, persistent storage, Helm, automated testing, and continuous integration.
