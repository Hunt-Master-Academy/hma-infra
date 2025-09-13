#!/bin/bash
# Hunt Master Academy - Integration Test Runner
# Comprehensive script to run all integration tests with proper setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_NETWORK="docker_hma_network"
PYTHON_IMAGE="python:3.12-slim"

echo -e "${BLUE}🚀 Hunt Master Academy - Integration Test Runner${NC}"
echo -e "${BLUE}================================================${NC}"

# Function to check if Docker services are running
check_services() {
    echo -e "${YELLOW}Checking Docker services...${NC}"

    services=("hma_postgres" "hma_redis" "hma_minio" "hma-content-bridge" "hma-ml-server")
    missing_services=()

    for service in "${services[@]}"; do
        if ! docker ps --format "table {{.Names}}" | grep -q "^${service}$"; then
            missing_services+=("$service")
        fi
    done

    if [ ${#missing_services[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing services: ${missing_services[*]}${NC}"
        echo -e "${YELLOW}💡 Start services with: docker compose -f docker/docker-compose.yml up -d${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ All required services are running${NC}"
}

# Function to run tests
run_tests() {
    local test_type="$1"
    local test_class="$2"
    local description="$3"

    echo -e "${BLUE}🧪 Running ${description}...${NC}"

    docker run --rm --network ${TEST_NETWORK} \
        -v "${PROJECT_ROOT}:/app" \
        -w /app \
        -e PYTHONPATH=/app \
        --user $(id -u):$(id -g) \
        ${PYTHON_IMAGE} bash -c "
        pip install -r requirements-test.txt > /dev/null 2>&1
        python -m pytest tests/test_service_integration.py${test_class} \
            -v \
            --tb=short \
            --junitxml=test-results-${test_type}.xml \
            --html=test-report-${test_type}.html \
            --self-contained-html
    "

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ ${description} completed successfully${NC}"
    else
        echo -e "${RED}❌ ${description} failed${NC}"
        return 1
    fi
}

# Function to run performance tests
run_performance_tests() {
    echo -e "${BLUE}⚡ Running Performance Tests...${NC}"

    docker run --rm --network ${TEST_NETWORK} \
        -v "${PROJECT_ROOT}:/app" \
        -w /app \
        -e PYTHONPATH=/app \
        --user $(id -u):$(id -g) \
        ${PYTHON_IMAGE} bash -c "
        pip install -r requirements-test.txt > /dev/null 2>&1
        python -m pytest tests/test_service_integration.py::TestPerformance \
            -v \
            --tb=short \
            -s \
            --junitxml=test-results-performance.xml \
            --html=test-report-performance.html \
            --self-contained-html
    "

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Performance tests completed successfully${NC}"
    else
        echo -e "${RED}❌ Performance tests failed${NC}"
        return 1
    fi
}

# Function to generate report
generate_report() {
    echo -e "${BLUE}📊 Generating Integration Test Report...${NC}"

    docker run --rm --network ${TEST_NETWORK} \
        -v "${PROJECT_ROOT}:/app" \
        -w /app \
        -e PYTHONPATH=/app \
        --user $(id -u):$(id -g) \
        ${PYTHON_IMAGE} bash -c "
        pip install -r requirements-test.txt > /dev/null 2>&1
        python tests/test_service_integration.py --report
    "

    echo -e "${GREEN}✅ Test report generated: integration_test_report.json${NC}"
}

# Function to run all tests
run_all_tests() {
    echo -e "${BLUE}🎯 Running Complete Integration Test Suite${NC}"
    echo -e "${BLUE}=========================================${NC}"

    local start_time=$(date +%s)

    # Run test categories
    run_tests "health" "::TestServiceHealth" "Service Health Tests" || return 1
    run_tests "auth" "::TestAuthentication" "Authentication Tests" || return 1
    run_tests "dataflow" "::TestDataFlow" "Data Flow Tests" || return 1
    run_tests "e2e" "::TestEndToEndWorkflows" "End-to-End Workflow Tests" || return 1
    run_tests "error" "::TestErrorHandling" "Error Handling Tests" || return 1

    # Run performance tests
    run_performance_tests || return 1

    # Generate final report
    generate_report

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo -e "${GREEN}🎉 All integration tests completed successfully!${NC}"
    echo -e "${GREEN}⏱️  Total execution time: ${duration} seconds${NC}"
    echo -e "${GREEN}📁 Test results saved to:${NC}"
    echo -e "   - test-results-*.xml (JUnit format)"
    echo -e "   - test-report-*.html (HTML reports)"
    echo -e "   - integration_test_report.json (Summary)"
    echo -e "   - integration_test.log (Detailed logs)"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  all          Run complete integration test suite"
    echo "  health       Run service health tests only"
    echo "  auth         Run authentication tests only"
    echo "  dataflow     Run data flow tests only"
    echo "  e2e          Run end-to-end workflow tests only"
    echo "  performance  Run performance tests only"
    echo "  error        Run error handling tests only"
    echo "  report       Generate test report only"
    echo "  check        Check if all required services are running"
    echo "  help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 all                    # Run all tests"
    echo "  $0 health                 # Quick health check"
    echo "  $0 performance            # Load testing only"
    echo ""
    echo "Environment:"
    echo "  - Requires Docker services: hma_postgres, hma_redis, hma_minio, hma-content-bridge, hma-ml-server"
    echo "  - Network: docker_hma_network"
    echo "  - Python: 3.12+ with test dependencies"
}

# Main script logic
case "${1:-all}" in
    "all")
        check_services
        run_all_tests
        ;;
    "health")
        check_services
        run_tests "health" "::TestServiceHealth" "Service Health Tests"
        ;;
    "auth")
        check_services
        run_tests "auth" "::TestAuthentication" "Authentication Tests"
        ;;
    "dataflow")
        check_services
        run_tests "dataflow" "::TestDataFlow" "Data Flow Tests"
        ;;
    "e2e")
        check_services
        run_tests "e2e" "::TestEndToEndWorkflows" "End-to-End Workflow Tests"
        ;;
    "performance")
        check_services
        run_performance_tests
        ;;
    "error")
        check_services
        run_tests "error" "::TestErrorHandling" "Error Handling Tests"
        ;;
    "report")
        generate_report
        ;;
    "check")
        check_services
        echo -e "${GREEN}✅ All services are running and ready for testing${NC}"
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac
