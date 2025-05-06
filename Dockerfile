# Use PowerShell as base image
FROM mcr.microsoft.com/powershell:7.5-ubuntu-24.04

# Set working directory
WORKDIR /app

# Labels
LABEL maintainer="Philip S. Wright" \
      description="Development environment for Proxmox Helper Script" \
      version="1.0.0"

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install PowerShell modules
RUN pwsh -Command \
    "Set-PSRepository PSGallery -InstallationPolicy Trusted; \
     Install-Module -Name Pester -MinimumVersion 5.0.0 -Force; \
     Install-Module -Name PSScriptAnalyzer -Force"

# Copy project files
COPY . .

# Set PowerShell as entrypoint
ENTRYPOINT ["pwsh"]

# Default command to run tests
CMD ["-File", "build.ps1", "-Task", "Test"]
