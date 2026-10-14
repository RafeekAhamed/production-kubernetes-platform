[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$')]
    [string]$ImageTag,

    [string]$Namespace = "helm-validation",

    [string]$ReleaseName = "production-platform",

    [string]$ChartPath = "helm/production-platform",

    [string]$ImageRepository = "rafeekahamed/production-kubernetes-platform"
)

$ErrorActionPreference = "Stop"

function Stop-Deployment {
    param([string]$Message)

    throw $Message
}

$PortForwardProcess = $null
$PortForwardLog = Join-Path $env:TEMP "production-platform-port-forward.log"
$PortForwardErrorLog = Join-Path $env:TEMP "production-platform-port-forward-error.log"
$LocalPort = 18085

try {
    Write-Host "`n=== Production Kubernetes Platform Deployment ===" -ForegroundColor Cyan

    # 1. Verify required tools.
    foreach ($Tool in @("kubectl", "helm")) {
        if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
            Stop-Deployment "Required tool '$Tool' is not installed or not on PATH."
        }
    }

    # 2. Verify Kubernetes connectivity.
    Write-Host "`nChecking Kubernetes connectivity..." -ForegroundColor Yellow

    kubectl cluster-info

    if ($LASTEXITCODE -ne 0) {
        Stop-Deployment "Cannot connect to the Kubernetes cluster."
    }

    # 3. Verify the namespace.
    kubectl get namespace $Namespace *> $null

    if ($LASTEXITCODE -ne 0) {
        Stop-Deployment "Namespace '$Namespace' does not exist."
    }

    # 4. Validate the Helm chart.
    Write-Host "`nValidating Helm chart..." -ForegroundColor Yellow

    helm lint $ChartPath

    if ($LASTEXITCODE -ne 0) {
        Stop-Deployment "Helm chart validation failed."
    }

    # 5. Upgrade the release while preserving existing values.
    Write-Host "`nDeploying image: ${ImageRepository}:${ImageTag}" -ForegroundColor Yellow

    helm upgrade $ReleaseName $ChartPath `
        --namespace $Namespace `
        --reuse-values `
        --set-string "image.repository=$ImageRepository" `
        --set-string "image.tag=$ImageTag" `
        --wait `
        --timeout 180s

    if ($LASTEXITCODE -ne 0) {
        Stop-Deployment "Helm upgrade failed."
    }

    # 6. Verify the rollout.
    Write-Host "`nWaiting for deployment rollout..." -ForegroundColor Yellow

    kubectl rollout status deployment/production-platform-backend `
        --namespace $Namespace `
        --timeout=180s

    if ($LASTEXITCODE -ne 0) {
        Stop-Deployment "Deployment rollout failed."
    }

    # 7. Display deployment status.
    Write-Host "`n=== Deployment Status ===" -ForegroundColor Green

    kubectl get deployments,pods -n $Namespace

    if ($LASTEXITCODE -ne 0) {
        Stop-Deployment "Could not retrieve deployment status."
    }

    # 8. Start a temporary port-forward.
    Write-Host "`n=== Application Health Checks ===" -ForegroundColor Cyan

    $PortForwardProcess = Start-Process `
        -FilePath "kubectl" `
        -ArgumentList @(
            "port-forward",
            "--namespace", $Namespace,
            "service/production-platform-service",
            "${LocalPort}:80"
        ) `
        -PassThru `
        -RedirectStandardOutput $PortForwardLog `
        -RedirectStandardError $PortForwardErrorLog

    # 9. Wait until the application responds.
    $ForwardReady = $false

    for ($Attempt = 0; $Attempt -lt 20; $Attempt++) {
        if ($PortForwardProcess.HasExited) {
            $LogDetails = Get-Content $PortForwardErrorLog -Raw -ErrorAction SilentlyContinue
            Stop-Deployment "kubectl port-forward exited unexpectedly. $LogDetails"
        }

        try {
            $HealthResponse = Invoke-RestMethod `
                -Uri "http://127.0.0.1:$LocalPort/health" `
                -TimeoutSec 2

            if ($HealthResponse.status -eq "healthy") {
                $ForwardReady = $true
                break
            }
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }

    if (-not $ForwardReady) {
        $LogDetails = Get-Content $PortForwardErrorLog -Raw -ErrorAction SilentlyContinue
        Stop-Deployment "Application health endpoint did not respond successfully. $LogDetails"
    }

    # 10. Verify application health, readiness, and database connectivity.
    foreach ($Endpoint in @("/health", "/ready", "/db-health")) {
        Write-Host "`nChecking $Endpoint ..." -ForegroundColor Yellow

        $Response = Invoke-RestMethod `
            -Uri "http://127.0.0.1:$LocalPort$Endpoint" `
            -TimeoutSec 10

        switch ($Endpoint) {
            "/health" {
                if ($Response.status -ne "healthy") {
                    Stop-Deployment "Application health check failed."
                }
            }

            "/ready" {
                if ($Response.status -ne "ready") {
                    Stop-Deployment "Application readiness check failed."
                }
            }

            "/db-health" {
                if ($Response.status -ne "connected") {
                    Stop-Deployment "Database connectivity check failed."
                }
            }
        }

        $Response | ConvertTo-Json -Depth 5
    }

    Write-Host "`nDeployment and all health checks completed successfully." `
        -ForegroundColor Green
}
catch {
    Write-Host "`nDEPLOYMENT FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Stop only the port-forward process started by this script.
    if ($null -ne $PortForwardProcess) {
        if (-not $PortForwardProcess.HasExited) {
            Stop-Process -Id $PortForwardProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }
}