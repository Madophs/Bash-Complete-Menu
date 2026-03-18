#!/bin/bash

TEST_SCRIPT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
UNIT_TEST_DIR="${TEST_SCRIPT_ROOT}/unit"

source "${TEST_SCRIPT_ROOT}/fwktest/fwktest_incl.sh"
fwktest_add_test_dir "${UNIT_TEST_DIR}"
fwktest_evaluate "${1}"

