#!/bin/bash

# build_and_deploy_dashboard.sh
# Build dashboard on cluster and push to GitHub for immediate deployment

set -e

# Configuration
DASHBOARD_DIR="$HOME/research/mosquito-alert-model-monitor"
REPO_URL="git@github.com:Mosquito-Alert/mosquito-alert-model-monitor.git"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Building dashboard on cluster...${NC}"

# Change to dashboard directory
cd "$DASHBOARD_DIR"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Not a git repository. Please clone the repo first.${NC}"
    exit 1
fi

# Load required modules for cluster
echo -e "${YELLOW}📦 Loading cluster modules...${NC}"
module load R/4.4.2-gfbf-2024a || module load R/4.3.2-gfbf-2023a
module load Miniconda3/24.7.1-0

# Activate conda environment if available
if conda info --envs | grep -q mosquito-alert-monitor; then
    echo -e "${YELLOW}🐍 Activating conda environment...${NC}"
    conda activate mosquito-alert-monitor
fi

# Pull latest changes
echo -e "${YELLOW}⬇️  Pulling latest changes...${NC}"
git pull origin main

# Check if quarto is available
if ! command -v quarto &> /dev/null; then
    echo -e "${YELLOW}📥 Installing Quarto...${NC}"
    # Install Quarto if not available
    wget https://github.com/quarto-dev/quarto-cli/releases/download/v1.4.549/quarto-1.4.549-linux-amd64.deb
    sudo dpkg -i quarto-1.4.549-linux-amd64.deb || {
        echo -e "${RED}❌ Could not install Quarto system-wide. Using local installation...${NC}"
        rm -f quarto-1.4.549-linux-amd64.deb
        
        # Try local installation
        mkdir -p ~/.local/bin
        cd ~/.local/bin
        wget https://github.com/quarto-dev/quarto-cli/releases/download/v1.4.549/quarto-1.4.549-linux-amd64.tar.gz
        tar -xzf quarto-1.4.549-linux-amd64.tar.gz
        ln -sf quarto-1.4.549/bin/quarto quarto
        export PATH="$HOME/.local/bin:$PATH"
        cd "$DASHBOARD_DIR"
    }
fi

# Check R dependencies
echo -e "${YELLOW}📊 Checking R dependencies...${NC}"
Rscript -e "
required_packages <- c('DT', 'plotly', 'jsonlite', 'lubridate', 'dplyr', 'purrr', 'stringr', 'ggplot2', 'yaml', 'htmltools', 'knitr', 'rmarkdown')
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,'Package'])]
if(length(missing_packages) > 0) {
  cat('Installing missing packages:', paste(missing_packages, collapse=', '), '\n')
  install.packages(missing_packages, repos='https://cloud.r-project.org', lib=.libPaths()[1])
} else {
  cat('All required packages are installed.\n')
}
"

# Render the dashboard
echo -e "${GREEN}🎨 Rendering dashboard...${NC}"
quarto render

# Check if render was successful
if [ ! -d "docs" ] || [ ! -f "docs/index.html" ]; then
    echo -e "${RED}❌ Dashboard rendering failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Dashboard rendered successfully!${NC}"

# Add and commit changes
echo -e "${YELLOW}📝 Committing changes...${NC}"
git add docs/
git add data/

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo -e "${GREEN}ℹ️  No changes to commit - dashboard is up to date${NC}"
else
    # Create commit message with timestamp and job summary
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    COMMIT_MSG="Dashboard update: $TIMESTAMP (cluster build)"
    
    git commit -m "$COMMIT_MSG"
    
    # Push changes
    echo -e "${GREEN}⬆️  Pushing to GitHub...${NC}"
    git push origin main
    
    echo -e "${GREEN}🎉 Dashboard updated and deployed!${NC}"
    echo -e "${GREEN}📱 View at: https://mosquito-alert.github.io/mosquito-alert-model-monitor/${NC}"
fi

echo -e "${GREEN}✨ Build complete!${NC}"
