#!/bin/bash

# Create new project from ubuntu-project template
# Usage: ./cp.sh -p <platform-name> -n <project-name> -u <github-user-name> -d "<project-description>" -l <target location> -t <template directory>

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load DOCKER_ROOT_PATH from .env (go up 3 levels from projects/ to reach docker-platforms/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# Use DOCKER_ROOT_PATH or fallback to default
DOCKER_ROOT_PATH="${DOCKER_ROOT_PATH:-/var/services/homes/jungsam/dockers}"

# Scripts directory
SCRIPTS_DIR="$DOCKER_ROOT_PATH/_manager/scripts"
CREATE_DB_SCRIPT="$SCRIPTS_DIR/create-project-db.js"
UPDATE_REPO_SCRIPT="$SCRIPTS_DIR/update-repositories.js"

# Default values
TARGET_LOCATION="./"
TEMPLATE_DIRECTORY="$DOCKER_ROOT_PATH/_templates/docker/ubuntu-project"
PLATFORM_NAME=""
PROJECT_NAME=""
GITHUB_USER=""
PROJECT_DESCRIPTION=""
GIT_ENABLED="true"

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Convert string to snake_case
to_snake_case() {
    echo "$1" | sed 's/-/_/g' | sed 's/\([A-Z]\)/_\1/g' | tr '[:upper:]' '[:lower:]' | sed 's/^_//'
}

# 사용법 출력
show_usage() {
    echo "Usage: $0 -p <platform-name> -n <project-name> [-u <github-user-name>] [-d \"<project-description>\"] [-l <target-location>] [-t <template-directory>]"
    echo ""
    echo "Create a new project from ubuntu-project template"
    echo ""
    echo "Options:"
    echo "  -p  Platform name (required)"
    echo "  -n  Project name (required)"
    echo "  -u  GitHub username (default: current user)"
    echo "  -d  Project description (default: <project-name>)"
    echo "  -l  Target location (default: ./)"
    echo "  -t  Template directory (default: $DOCKER_ROOT_PATH/_templates/ubuntu-project)"
    echo "  -g  Initialize Git repository (true|false, default: true)"
    echo "  -h  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -p ubuntu-sam -n my-ecommerce"
    echo "  $0 -p ubuntu-sam -n blog-platform -u myuser -d \"My Blog Platform\""
}

# Parse command line arguments
while getopts "p:n:u:d:l:t:g:h" opt; do
    case $opt in
        p)
            PLATFORM_NAME="$OPTARG"
            ;;
        n)
            PROJECT_NAME="$OPTARG"
            ;;
        u)
            GITHUB_USER="$OPTARG"
            ;;
        d)
            PROJECT_DESCRIPTION="$OPTARG"
            ;;
        l)
            TARGET_LOCATION="$OPTARG"
            ;;
        t)
            TEMPLATE_DIRECTORY="$OPTARG"
            ;;
        g)
            GIT_ENABLED="$OPTARG"
            ;;
        h)
            show_usage
            exit 0
            ;;
        \?)
            log_error "Invalid option: -$OPTARG"
            show_usage
            exit 1
            ;;
        :)
            log_error "Option -$OPTARG requires an argument."
            exit 1
            ;;
    esac
done

GIT_ENABLED=$(echo "$GIT_ENABLED" | tr "[:upper:]" "[:lower:]")
if [ "$GIT_ENABLED" != "true" ] && [ "$GIT_ENABLED" != "false" ]; then
    log_error "Invalid value for -g. Use true or false."
    exit 1
fi

# Validate required arguments
if [ -z "$PLATFORM_NAME" ]; then
    log_error "Platform name (-p) is required"
    show_usage
    exit 1
fi

if [ -z "$PROJECT_NAME" ]; then
    log_error "Project name (-n) is required"
    show_usage
    exit 1
fi

# Set default values for optional parameters
if [ -z "$GITHUB_USER" ]; then
    GITHUB_USER="$(whoami)"
    log_info "Using current user as GitHub user: $GITHUB_USER"
fi

if [ -z "$PROJECT_DESCRIPTION" ]; then
    PROJECT_DESCRIPTION="$PROJECT_NAME"
fi

# Check if template directory exists
if [ ! -d "$TEMPLATE_DIRECTORY" ]; then
    log_error "Template directory '$TEMPLATE_DIRECTORY' does not exist"
    exit 1
fi

# 프로젝트명 유효성 검사
validate_project_name() {
    local project_name="$1"

    # 프로젝트명 형식 확인 (영문, 숫자, 하이픈만 허용)
    if [[ ! "$project_name" =~ ^[a-zA-Z0-9-]+$ ]]; then
        log_error "프로젝트명은 영문, 숫자, 하이픈(-)만 사용할 수 있습니다."
        exit 1
    fi

    # 절대 경로로 변환
    TARGET_LOCATION=$(cd "$TARGET_LOCATION" && pwd)

    # 프로젝트 디렉토리가 이미 존재하는지 확인
    if [ -d "$TARGET_LOCATION/$project_name" ]; then
        log_error "프로젝트 '$project_name'가 이미 존재합니다: $TARGET_LOCATION/$project_name"
        exit 1
    fi
}

# Load platform environment variables
load_platform_env() {
    local platform_name="$1"
    local platform_env_file="$DOCKER_ROOT_PATH/platforms/$platform_name/.env"

    if [ ! -f "$platform_env_file" ]; then
        log_error "Platform .env file not found: $platform_env_file"
        exit 1
    fi

    log_info "Loading platform environment from: $platform_env_file"
    source "$platform_env_file"

    # Export required variables
    export MYSQL_HOST
    export MYSQL_PORT
    export MYSQL_USER
    export MYSQL_PASSWORD
    export POSTGRES_HOST
    export POSTGRES_PORT
    export POSTGRES_USER
    export POSTGRES_PASSWORD
    export PLATFORM_PORT_START

    log_success "Platform environment loaded"
    log_info "MySQL: ${MYSQL_HOST}:${MYSQL_PORT}"
    log_info "PostgreSQL: ${POSTGRES_HOST}:${POSTGRES_PORT}"
    log_info "Platform port start: ${PLATFORM_PORT_START}"
}

# Create databases using create-project-db.js
create_databases() {
    local platform_name="$1"
    local project_name="$2"

    if [ ! -f "$CREATE_DB_SCRIPT" ]; then
        log_error "Database creation script not found: $CREATE_DB_SCRIPT"
        exit 1
    fi

    log_info "Creating databases for project..."

    # Create MySQL database
    log_info "Creating MySQL database..."
    MYSQL_RESULT=$(node "$CREATE_DB_SCRIPT" "$platform_name" "$project_name" mysql 2>&1)

    if [ $? -eq 0 ]; then
        log_success "MySQL database created successfully"
        echo "$MYSQL_RESULT"

        # Extract database name from output
        MYSQL_DB_NAME=$(echo "$MYSQL_RESULT" | grep "DB_NAME=" | cut -d'=' -f2)
        MYSQL_DB_USER=$(echo "$MYSQL_RESULT" | grep "DB_USER=" | cut -d'=' -f2)
        MYSQL_DB_PASSWORD=$(echo "$MYSQL_RESULT" | grep "DB_PASSWORD=" | cut -d'=' -f2)
    else
        log_error "Failed to create MySQL database"
        echo "$MYSQL_RESULT"
        exit 1
    fi

    # Create PostgreSQL database
    log_info "Creating PostgreSQL database..."
    PG_RESULT=$(node "$CREATE_DB_SCRIPT" "$platform_name" "$project_name" postgresql 2>&1)

    if [ $? -eq 0 ]; then
        log_success "PostgreSQL database created successfully"
        echo "$PG_RESULT"

        # Extract database name from output
        POSTGRES_DB_NAME=$(echo "$PG_RESULT" | grep "DB_NAME=" | cut -d'=' -f2)
        POSTGRES_DB_USER=$(echo "$PG_RESULT" | grep "DB_USER=" | cut -d'=' -f2)
        POSTGRES_DB_PASSWORD=$(echo "$PG_RESULT" | grep "DB_PASSWORD=" | cut -d'=' -f2)
    else
        log_error "Failed to create PostgreSQL database"
        echo "$PG_RESULT"
        exit 1
    fi

    # Generate DB name using snake_case
    local platform_snake=$(to_snake_case "$platform_name")
    local project_snake=$(to_snake_case "$project_name")
    PROJECT_DB_NAME="${platform_snake}__${project_snake}_db"

    export MYSQL_DB_NAME
    export MYSQL_DB_USER
    export MYSQL_DB_PASSWORD
    export POSTGRES_DB_NAME
    export POSTGRES_DB_USER
    export POSTGRES_DB_PASSWORD
    export PROJECT_DB_NAME

    log_success "Databases created successfully"
}

# Calculate port variables
calculate_ports() {
    local base_port="$PLATFORM_PORT_START"

    log_info "Calculating port assignments from base port: $base_port"

    # Calculate PORT_1 to PORT_19
    for i in {1..19}; do
        local port=$((base_port + i))
        eval "export PORT_$i=$port"
    done

    log_success "Port assignments calculated"
    log_info "PORT_1 (BE Node.js): ${PORT_1}"
    log_info "PORT_6 (FE Next.js): ${PORT_6}"
}

# 템플릿 복사
copy_template() {
    local project_name="$1"
    local template_path="$2"
    local target_path="$3"

    log_info "Copying ubuntu-project template..."

    # 대상 디렉토리 생성
    mkdir -p "$target_path/$project_name"

    # 템플릿 전체 복사
    cp -r "$template_path"/* "$target_path/$project_name/"

    # 숨김 파일들도 복사 (.env, .gitignore 등)
    cp -r "$template_path"/.[!.]* "$target_path/$project_name/" 2>/dev/null || true

    log_success "Template copied successfully"
}

# 변수 치환 실행
substitute_template_variables() {
    local project_name="$1"
    local target_path="$2"

    log_info "Substituting template variables..."

    local project_path="$target_path/$project_name"

    # Function to substitute variables in a single env file
    substitute_env_file() {
        local env_file="$1"
        local file_desc="$2"

        if [ -f "$env_file" ]; then
            log_info "Substituting variables in $file_desc..."

            # Platform database connection variables
            sed -i "s|\${MYSQL_HOST}|$MYSQL_HOST|g" "$env_file"
            sed -i "s|\${MYSQL_PORT}|$MYSQL_PORT|g" "$env_file"
            sed -i "s|\${MYSQL_USER}|$MYSQL_USER|g" "$env_file"
            sed -i "s|\${MYSQL_PASSWORD}|$MYSQL_PASSWORD|g" "$env_file"

            sed -i "s|\${POSTGRES_HOST}|$POSTGRES_HOST|g" "$env_file"
            sed -i "s|\${POSTGRES_PORT}|$POSTGRES_PORT|g" "$env_file"
            sed -i "s|\${POSTGRES_USER}|$POSTGRES_USER|g" "$env_file"
            sed -i "s|\${POSTGRES_PASSWORD}|$POSTGRES_PASSWORD|g" "$env_file"

            # Project database name
            sed -i "s|{PROJECT_DB_NAME}|$PROJECT_DB_NAME|g" "$env_file"

            # Port variables (PORT_1 to PORT_19)
            for i in {1..19}; do
                local port_var="PORT_$i"
                local port_value="${!port_var}"
                sed -i "s|\${PORT_$i}|$port_value|g" "$env_file"
            done

            log_success "Variables substituted in $file_desc"
        fi
    }

    # Substitute variables in all .env files
    substitute_env_file "$project_path/.env" ".env file"
    substitute_env_file "$project_path/.env.dev" ".env.dev file"
    substitute_env_file "$project_path/.env.prod" ".env.prod file"

    # 다른 파일들의 변수 치환
    find "$project_path" -type f \( -name "*.json" -o -name "*.ts" -o -name "*.js" -o -name "*.md" \) -exec sed -i "s/{projectName}/$project_name/g" {} \;
    find "$project_path" -type f \( -name "*.json" -o -name "*.ts" -o -name "*.js" -o -name "*.md" \) -exec sed -i "s/{projectDescription}/$PROJECT_DESCRIPTION/g" {} \;
    find "$project_path" -type f \( -name "*.json" -o -name "*.ts" -o -name "*.js" -o -name "*.md" \) -exec sed -i "s/{githubUser}/$GITHUB_USER/g" {} \;

    # 날짜 변수 치환
    local current_date=$(date +%Y-%m-%d)
    find "$project_path" -type f -name "*.md" -exec sed -i "s/{currentDate}/$current_date/g" {} \;

    log_success "Template variable substitution completed"
}

# .gitignore 파일 생성
create_gitignore() {
    local project_name="$1"
    local target_path="$2"

    log_info "Creating .gitignore file..."

    local project_path="$target_path/$project_name"

    cat > "$project_path/.gitignore" << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Build outputs
.next/
dist/
build/

# Logs
logs
*.log

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory
coverage/

# Database
*.sqlite
*.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Project specific
temp/
tmp/
EOF

    log_success ".gitignore file created"
}

update_repository_records() {
    local mode="$1"
    shift

    if [ ! -f "$UPDATE_REPO_SCRIPT" ]; then
        log_warning "Repositories update script not found: $UPDATE_REPO_SCRIPT"
        return
    fi

    node "$UPDATE_REPO_SCRIPT" "$mode" "$@"
}

update_projects_json() {
    local project_name="$1"
    local platform_name="$2"
    local description="$3"
    local github_user="$4"
    local status="$5"

    local projects_file="$DOCKER_ROOT_PATH/_manager/data/projects.json"
    local update_projects_script="$SCRIPTS_DIR/update-projects.js"

    if [ ! -f "$projects_file" ]; then
        log_warning "Projects data file not found: $projects_file"
        return
    fi

    if [ ! -f "$SCRIPTS_DIR/port-allocator.js" ]; then
        log_warning "Port allocator script not found: $SCRIPTS_DIR/port-allocator.js"
        return
    fi

    if [ ! -f "$update_projects_script" ]; then
        log_warning "Projects update script not found: $update_projects_script"
        return
    fi

    local project_sn
    project_sn=$(node "$SCRIPTS_DIR/port-allocator.js" next-project "$projects_file" "$platform_name" 2>/dev/null | tr -d $'\r\n')
    if [ -z "$project_sn" ]; then
        project_sn=0
    fi

    local timestamp
    timestamp=$(date -Iseconds --utc)

    log_info "Updating projects.json..."
    node "$update_projects_script" "$projects_file" "$project_name" "$platform_name" "$description" "$github_user" "$status" "$timestamp" "$project_sn"
}

# Validate project name
validate_project_name "$PROJECT_NAME"

# Load platform environment
load_platform_env "$PLATFORM_NAME"

# Calculate ports
calculate_ports

# Create databases
create_databases "$PLATFORM_NAME" "$PROJECT_NAME"

echo ""
log_info "==================================================="
log_info "Creating new project: $PROJECT_NAME"
log_info "Platform: $PLATFORM_NAME"
log_info "GitHub user: $GITHUB_USER"
log_info "Description: $PROJECT_DESCRIPTION"
log_info "Target location: $TARGET_LOCATION"
log_info "Template directory: $TEMPLATE_DIRECTORY"
log_info "==================================================="
echo ""

# 프로젝트 생성
copy_template "$PROJECT_NAME" "$TEMPLATE_DIRECTORY" "$TARGET_LOCATION"
substitute_template_variables "$PROJECT_NAME" "$TARGET_LOCATION"
create_gitignore "$PROJECT_NAME" "$TARGET_LOCATION"

# Git 저장소 생성 (xgit 사용)
REPO_LOCAL_PATH="platforms/$PLATFORM_NAME/projects/$PROJECT_NAME"

log_info "Initializing Git repository..."
if [ "$GIT_ENABLED" = "true" ]; then
    if command -v xgit &> /dev/null; then
        cd "$TARGET_LOCATION/$PROJECT_NAME"
        xgit -e make -u "$GITHUB_USER" -n "$PROJECT_NAME" -d "$PROJECT_DESCRIPTION" || log_warning "Git repository initialization failed (continuing)"
        cd - > /dev/null
    else
        log_warning "xgit command not found. Please initialize Git repository manually."
    fi
    update_repository_records add-github "$PROJECT_NAME" project "$GITHUB_USER" "$PROJECT_DESCRIPTION" "$REPO_LOCAL_PATH"
else
    log_info "Skipping Git repository initialization (-g=false)"
    update_repository_records add-nogit "$PROJECT_NAME" project "$PROJECT_DESCRIPTION" "$REPO_LOCAL_PATH"
fi

update_projects_json "$PROJECT_NAME" "$PLATFORM_NAME" "$PROJECT_DESCRIPTION" "$GITHUB_USER" "development"

echo ""
log_success "=========================================="
log_success "Project '$PROJECT_NAME' created successfully!"
log_success "=========================================="
echo ""
log_info "📦 Project Details:"
echo "   Location: $TARGET_LOCATION/$PROJECT_NAME"
echo "   Platform: $PLATFORM_NAME"
echo ""
log_info "🗄️  Database Information:"
echo "   MySQL Database: $MYSQL_DB_NAME"
echo "   PostgreSQL Database: $POSTGRES_DB_NAME"
echo ""
log_info "🔌 Port Assignments:"
echo "   Backend (Node.js): ${PORT_1}"
echo "   Backend (Python): ${PORT_2}"
echo "   GraphQL API: ${PORT_3}"
echo "   REST API: ${PORT_4}"
echo "   Frontend (Next.js): ${PORT_6}"
echo "   Frontend (Svelte): ${PORT_7}"
echo ""
log_info "📝 Next Steps:"
echo "   1. cd $TARGET_LOCATION/$PROJECT_NAME"
echo "   2. Review the .env file"
echo "   3. Install dependencies and start development"
echo ""
log_success "Project is ready! 🚀"
