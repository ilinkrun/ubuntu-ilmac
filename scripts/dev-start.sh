#!/bin/bash

# dev-start.sh - ubuntu-ilmac 개발 환경 시작 스크립트
# Usage: ./dev-start.sh [service-name]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Docker 및 Docker Compose 확인
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되지 않았습니다."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose가 설치되지 않았습니다."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker 데몬이 실행되지 않았습니다."
        exit 1
    fi
}

# 환경변수 파일 확인
check_env() {
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        if [ -f "$PROJECT_ROOT/.env.sample" ]; then
            log_warning ".env 파일이 없습니다. .env.sample을 복사합니다."
            cp "$PROJECT_ROOT/.env.sample" "$PROJECT_ROOT/.env"
            log_info ".env 파일을 수정한 후 다시 실행해주세요."
            exit 1
        else
            log_error ".env 파일과 .env.sample 파일이 모두 없습니다."
            exit 1
        fi
    fi
}

# 네트워크 생성
create_networks() {
    log_info "Docker 네트워크를 생성합니다..."

    # infrastructure 네트워크 생성
    if ! docker network ls | grep -q "infrastructure"; then
        docker network create infrastructure
        log_success "infrastructure 네트워크가 생성되었습니다."
    fi

    # projects 네트워크 생성
    if ! docker network ls | grep -q "projects"; then
        docker network create projects
        log_success "projects 네트워크가 생성되었습니다."
    fi
}

# 개발 환경 시작
start_development() {
    local service_name="$1"

    cd "$PROJECT_ROOT"

    log_info "개발 환경을 시작합니다..."

    # 네트워크 생성
    create_networks

    if [ -n "$service_name" ]; then
        log_info "서비스 '$service_name'만 시작합니다..."
        docker-compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml up -d "$service_name"
    else
        log_info "모든 서비스를 시작합니다..."
        docker-compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml up -d
    fi

    # 서비스 상태 확인
    sleep 5
    log_info "서비스 상태를 확인합니다..."
    docker-compose -f docker/docker-compose.yml ps

    log_success "개발 환경이 시작되었습니다!"
    log_info "다음 URL로 접속할 수 있습니다:"
    echo "  - API Gateway: http://localhost:3000"
    echo "  - Auth Service: http://localhost:3001"
    echo "  - Database Service: http://localhost:3002"
    echo "  - Management Hub: http://localhost:3003"
    echo "  - PostgreSQL: localhost:5432"
    echo "  - Redis: localhost:6379"
}

# 도움말 출력
show_help() {
    echo "Usage: $0 [service-name]"
    echo ""
    echo "개발 환경을 시작합니다."
    echo ""
    echo "Options:"
    echo "  service-name    특정 서비스만 시작 (선택사항)"
    echo "  -h, --help      이 도움말을 출력"
    echo ""
    echo "Examples:"
    echo "  $0                    # 모든 서비스 시작"
    echo "  $0 auth-service       # Auth Service만 시작"
    echo "  $0 postgres           # PostgreSQL만 시작"
}

# 메인 실행
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            check_docker
            check_env
            start_development "$1"
            ;;
    esac
}

# 스크립트 실행
main "$@"