#!/usr/bin/bash

TEST_TEMP_DIR="/tmp/test_menu_complete"

mkdir -p "${TEST_TEMP_DIR}"

function clean_test_dir() {
    rm -rf "${TEST_TEMP_DIR}"/*
}

function create_test_file() {
    while (( $# > 0 ))
    do
        touch "${TEST_TEMP_DIR}/${1}"
        shift
    done
}

function create_test_dir() {
    while (( $# > 0 ))
    do
        mkdir -p "${TEST_TEMP_DIR}/${1}"
        shift
    done
}

function get_array_item_index() {
    local -n arr_ptr=${1}
    local -n arr_index_ptr=${2}
    local item_value="${3}"
    local -i i=0

    for (( ; i<${#arr_ptr[@]}; i+=1 ))
    do
        [[ "${item_value}" == "${arr_ptr[${i}]}" ]] && break
    done

    (( i >= ${#arr_ptr[@]} )) && arr_index_ptr=0 || arr_index_ptr=i
}

function assert_bash_completions() {
    local expected_command_at_cursor="${1}"
    local expected_value_in_completions="${2}"
    local expected_readline_completion="${3}"
    local -i READLINE_POINT=${4:-${#READLINE_LINE}}
    local command_at_cursor=""
    local -i command_at_cursor_pos=0
    local -a complist=()
    local -i complist_index=0

    __get_command_at_cursor "${READLINE_LINE}" ${READLINE_POINT}
    complist=( $(__get_completions "${command_at_cursor}") )
    fwktest_assert_string_equals "${expected_command_at_cursor}" "${command_at_cursor}"
    fwktest_assert_array_contains complist "${expected_value_in_completions}"
    get_array_item_index complist complist_index "${expected_value_in_completions}"
    __insert_completion_into_readline
    fwktest_assert_string_equals "${READLINE_LINE}" "${expected_readline_completion}"
}
