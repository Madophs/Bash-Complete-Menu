#!/bin/bash

source ../../bash_complete_menu.sh
source ./utils.sh

function test_cd_completion() {
    clean_test_dir
    create_test_dir 'test_dir'{0..3}
    local -a arr=( $(__get_completions "cd ${TEST_TEMP_DIR}/") )
    for (( i=0; i<3; i+=1 ))
    do
        fwktest_assert_string_equals "${arr[${i}]}" "${TEST_TEMP_DIR}/test_dir${i}"
    done
}

function test_cd_completion_with_spaces() {
    local READLINE_LINE="" READLINE_EXPE=""
    clean_test_dir
    create_test_dir 'test dir'{0..3}

    local IFS=$'\n' # directories may contain spaces
    READLINE_LINE="cd ${TEST_TEMP_DIR}/"
    READLINE_EXPE="cd ${TEST_TEMP_DIR}/test\\ dir2"
    assert_bash_completions "cd ${TEST_TEMP_DIR}/" "${TEST_TEMP_DIR}/test\\ dir2" "${READLINE_EXPE}"
}

function test_single_command_completion() {
    local READLINE_LINE="" READLINE_EXPE=""
    READLINE_LINE='gr'
    READLINE_EXPE='grep'
    assert_bash_completions 'gr' 'grep' "${READLINE_EXPE}"

    READLINE_LINE='  comp'
    READLINE_EXPE='  compgen'
    assert_bash_completions 'comp' 'compgen' "${READLINE_EXPE}"
}

function test_single_command_completion_with_params() {
    local READLINE_LINE="" READLINE_EXPE=""
    READLINE_LINE='git sta'
    READLINE_EXPE='git status'
    assert_bash_completions 'git sta' 'status' "${READLINE_EXPE}"
}

function test_complete_varname() {
    local READLINE_LINE="" READLINE_EXPE=""
    READLINE_LINE='echo $BASH_VER'
    READLINE_EXPE='echo $BASH_VERSION'
    assert_bash_completions 'BASH_VER' 'BASH_VERSION' "${READLINE_EXPE}"

    READLINE_LINE='echo ${BASH_VER'
    READLINE_EXPE='echo ${BASH_VERSINFO}'
    assert_bash_completions 'BASH_VER' 'BASH_VERSINFO' "${READLINE_EXPE}"

    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='sed "s/bash/${BASH_VER}'
    READLINE_EXPE='sed "s/bash/${BASH_VERSION}'
    assert_bash_completions 'BASH_VER' 'BASH_VERSION' "${READLINE_EXPE}" 21

    READLINE_LINE='sed "s/bash/$BASH_VER'
    READLINE_EXPE='sed "s/bash/$BASH_VERSION'
    assert_bash_completions 'BASH_VER' 'BASH_VERSION' "${READLINE_EXPE}"
}

function test_dir_completion() {
    local READLINE_LINE="" READLINE_EXPE=""
    READLINE_LINE='/'
    READLINE_EXPE='/etc'
    assert_bash_completions '/' '/etc' "${READLINE_EXPE}"
}

function test_command_after_pipe() {
    local READLINE_LINE="" READLINE_EXPE=""
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='date | hist'
    READLINE_EXPE='date | history'
    assert_bash_completions 'hist' 'history' "${READLINE_EXPE}"

    READLINE_LINE='git status | $(cat /etc/group | le)'
    READLINE_EXPE='git status | $(cat /etc/group | less)'
    assert_bash_completions 'le' 'less' "${READLINE_EXPE}" 33
}

function test_complete_in_command_substitution() {
    local READLINE_LINE="" READLINE_EXPE=""
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='echo "$(git sta)" | grep commit'
    READLINE_EXPE='echo "$(git status)" | grep commit'
    assert_bash_completions 'git sta' 'status' "${READLINE_EXPE}" 12

    READLINE_LINE='RES="$(date | grep -F "$(ec $format)'
    READLINE_EXPE='RES="$(date | grep -F "$(echo $format)'
    assert_bash_completions 'ec' 'echo' "${READLINE_EXPE}" 26

    READLINE_LINE='RES="$(date | grep -F "$(echo $format | cat < <(echo "$(git status --bran'
    READLINE_EXPE='RES="$(date | grep -F "$(echo $format | cat < <(echo "$(git status --branch'
    assert_bash_completions 'git status --bran' '--branch' "${READLINE_EXPE}"
}

function test_complete_in_process_substitution() {
    local READLINE_LINE="" READLINE_EXPE=""
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='cat < <(git l origin) | sed "s/a/f/g"'
    READLINE_EXPE='cat < <(git log origin) | sed "s/a/f/g"'
    assert_bash_completions 'git l' 'log' "${READLINE_EXPE}" 12

    READLINE_LINE='cat <(git l origin; history) | sed "s/a/f/g"'
    READLINE_EXPE='cat <(git log origin; history) | sed "s/a/f/g"'
    assert_bash_completions 'git l' 'log' "${READLINE_EXPE}" 10

    READLINE_LINE='cat <(git l origin; hi) | sed "s/a/f/g"'
    READLINE_EXPE='cat <(git l origin; history) | sed "s/a/f/g"'
    assert_bash_completions 'hi' 'history' "${READLINE_EXPE}" 20
}

# The following tests requires execution in interactive mode
# bash -i test.sh

function test_cd_completion_with_varname() {
    case $- in
        *i*) ;;
        *) cout warning "${__CYAN}${FUNCNAME[0]}${__BLK}:only in interactive mode!" && return ;;
    esac
    clean_test_dir
    create_test_dir 'test_dir'{0..3}
    export TEST_TEMP_DIR
    local -a arr=( $(__get_completions 'cd $TEST_TEMP_DIR/') )
    for (( i=0; i<3; i+=1 ))
    do
        fwktest_assert_string_equals "${arr[${i}]}" "\$TEST_TEMP_DIR/test_dir${i}"
    done

    local READLINE_LINE="" READLINE_EXPE=""
    READLINE_LINE='cd $TEST_TEMP_DIR/'
    READLINE_EXPE='cd $TEST_TEMP_DIR/test_dir1'
    assert_bash_completions 'cd $TEST_TEMP_DIR/' '$TEST_TEMP_DIR/test_dir1' "${READLINE_EXPE}"

    READLINE_LINE='cd ${TEST_TEMP_DIR}/'
    READLINE_EXPE='cd ${TEST_TEMP_DIR}/test_dir1'
    assert_bash_completions 'cd ${TEST_TEMP_DIR}/' '${TEST_TEMP_DIR}/test_dir1' "${READLINE_EXPE}"
}

function test_dir_completion_interactive() {
    case $- in
        *i*) ;;
        *) cout warning "${__CYAN}${FUNCNAME[0]}${__BLK}:only in interactive mode!" && return ;;
    esac
    clean_test_dir
    create_test_dir 'to_complete'
    local -a arr=( $(__get_completions '${TEST_TEMP_DIR}/') )
    fwktest_assert_array_contains arr '${TEST_TEMP_DIR}/to_complete'
}
