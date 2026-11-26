#!/bin/bash

source ../../bash_complete_menu.sh
source ./utils.sh

function test_cd_completion() {
    clean_test_dir
    create_test_dir 'test_dir'{0..3}
    local -a arr=()
    mapfile -t arr < <(__get_completions "cd ${TEST_TEMP_DIR}/")
    for (( i=0; i<3; i+=1 ))
    do
        fwktest_assert_string_equals "${arr[${i}]}" "${TEST_TEMP_DIR}/test_dir${i}"
    done
}

function test_cd_completion_with_spaces() {
    local READLINE_LINE="" READLINE_EXPE=""
    clean_test_dir
    create_test_dir 'test dir'{0..3}
    create_test_dir 'test dir0/fotos'
    create_test_dir 'test dir0/videos'

    local IFS=$'\n' # directories may contain spaces
    READLINE_LINE="cd ${TEST_TEMP_DIR}/"
    READLINE_EXPE="cd ${TEST_TEMP_DIR}/test\\ dir2"
    assert_bash_completions "cd ${TEST_TEMP_DIR}/" "${TEST_TEMP_DIR}/test\\ dir2" "${READLINE_EXPE}"

    READLINE_LINE="cd \"${TEST_TEMP_DIR}/"
    READLINE_EXPE="cd \"${TEST_TEMP_DIR}/test dir2"
    assert_bash_completions "${TEST_TEMP_DIR}/" "${TEST_TEMP_DIR}/test dir2" "${READLINE_EXPE}"

    pushd "${TEST_TEMP_DIR}" &> /dev/null
    READLINE_LINE="cd \""
    READLINE_EXPE="cd \"test dir2"
    assert_bash_completions "" "test dir2" "${READLINE_EXPE}"
    popd &> /dev/null

    pushd "${TEST_TEMP_DIR}" &> /dev/null
    READLINE_LINE="cd \"test dir0/"
    READLINE_EXPE="cd \"test dir0/videos"
    assert_bash_completions "test dir0/" "test dir0/videos" "${READLINE_EXPE}"
    popd &> /dev/null
}

function test_cd_dir_backspace_completion() {
    pushd "${TEST_TEMP_DIR}" &> /dev/null || { echo "Failed to pushd \${TEST_TEMP_DIR}"; exit 1; }
    clean_test_dir
    create_test_dir 'mega'{0..2}
    create_test_dir 'mga'{0..2}
    local command_at_cursor="" command_context=""
    local READLINE_LINE='cd me'
    local -i READLINE_POINT=${4:-${#READLINE_LINE}}
    local -a complist=()
    __get_command_at_cursor "${READLINE_LINE}" ${READLINE_POINT}
    mapfile -t complist < <( __get_completions "${command_at_cursor}" )
    fwktest_assert_string_equals "${complist[*]}" "mega0 mega1 mega2"
    # Deleting the last character yields "cd m"
    __input_handling <<< $'\x7f' # backspace
    __get_command_at_cursor "${READLINE_LINE}" ${READLINE_POINT}
    mapfile -t complist < <( __get_completions "${command_at_cursor}" )
    fwktest_assert_string_equals "${READLINE_LINE}" "cd m"
    fwktest_assert_string_equals "${complist[*]}" "mega0 mega1 mega2 mga0 mga1 mga2"
    popd &> /dev/null || { echo "Failed to popd \${TEST_TEMP_DIR}"; exit 1; }
}

function test_cd_dir_backspace_in_the_middle_completion() {
    pushd "${TEST_TEMP_DIR}" &> /dev/null || { echo "Failed to pushd \${TEST_TEMP_DIR}"; exit 1; }
    clean_test_dir
    create_test_dir 'mega'{0..2}
    create_test_dir 'mga'{0..2}
    local command_at_cursor="" command_context=""
    local READLINE_LINE='cd meg'
    local -i READLINE_POINT=5 # Cursor at «cd me|g»
    local -a complist=()
    __get_command_at_cursor "${READLINE_LINE}" ${READLINE_POINT}
    mapfile -t complist < <( __get_completions "${command_at_cursor}" )
    fwktest_assert_string_equals "${complist[*]}" "mega0 mega1 mega2"
    # Deleting "e" yields "cd mg" ∴ filtering out mega* directories
    __input_handling <<< $'\x7f' # backspace
    __get_command_at_cursor "${READLINE_LINE}" ${READLINE_POINT}
    mapfile -t complist < <( __get_completions "${command_at_cursor}" )
    fwktest_assert_string_equals "${READLINE_LINE}" "cd mg"
    fwktest_assert_string_equals "${complist[*]}" "mga0 mga1 mga2"
    popd &> /dev/null || { echo "Failed to popd \${TEST_TEMP_DIR}"; exit 1; }
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
    guard_interactive_mode || return
    local READLINE_LINE="" READLINE_EXPE=""
    local IFS=$'\n'
    clean_test_dir
    create_test_dir "dir to file"
    create_test_dir "dir to file/another dir folder/and another one why not"
    create_test_dir "dir to file/another dir2 folder/and another one why not"
    create_test_file "dir to file2"
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='/'
    READLINE_EXPE='/etc'
    assert_bash_completions '/' '/etc' "${READLINE_EXPE}"

    READLINE_LINE='${TEST_TEMP_DIR}/dir\'
    READLINE_EXPE='${TEST_TEMP_DIR}/dir\ to\ file'
    assert_bash_completions '${TEST_TEMP_DIR}/dir\' '${TEST_TEMP_DIR}/dir\ to\ file' "${READLINE_EXPE}"

    READLINE_LINE='${TEST_TEMP_DIR}/dir\ '
    READLINE_EXPE='${TEST_TEMP_DIR}/dir\ to\ file'
    assert_bash_completions '${TEST_TEMP_DIR}/dir\ ' '${TEST_TEMP_DIR}/dir\ to\ file' "${READLINE_EXPE}"

    READLINE_LINE='${TEST_TEMP_DIR}/dir\ to\ file/another\ d/and\ another\ one\ why\ not'
    READLINE_EXPE='${TEST_TEMP_DIR}/dir\ to\ file/another\ dir2\ folder/and\ another\ one\ why\ not'
    assert_bash_completions '${TEST_TEMP_DIR}/dir\ to\ file/another\ d' \
                            '${TEST_TEMP_DIR}/dir\ to\ file/another\ dir2\ folder' \
                            "${READLINE_EXPE}" 40
}

function test_quoted_dir_completion() {
    guard_interactive_mode || return
    local READLINE_LINE="" READLINE_EXPE=""
    local IFS=$'\n'
    clean_test_dir
    create_test_dir "dir to file"
    create_test_dir "dir to file/another dir folder/and another one why not"
    create_test_dir "dir to file/another dir2 folder/and another one why not"
    create_test_file "dir to file2"
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='/'
    READLINE_EXPE='/etc'
    assert_bash_completions '/' '/etc' "${READLINE_EXPE}"

    READLINE_LINE='"${TEST_TEMP_DIR}/dir'
    READLINE_EXPE='"${TEST_TEMP_DIR}/dir to file'
    assert_bash_completions '${TEST_TEMP_DIR}/dir' '${TEST_TEMP_DIR}/dir to file' "${READLINE_EXPE}"

    READLINE_LINE='"${TEST_TEMP_DIR}/dir '
    READLINE_EXPE='"${TEST_TEMP_DIR}/dir to file'
    assert_bash_completions '${TEST_TEMP_DIR}/dir ' '${TEST_TEMP_DIR}/dir to file' "${READLINE_EXPE}"

    READLINE_LINE='"${TEST_TEMP_DIR}/dir to file/another d/and another one why not"'
    READLINE_EXPE='"${TEST_TEMP_DIR}/dir to file/another dir2 folder/and another one why not"'
    assert_bash_completions '${TEST_TEMP_DIR}/dir to file/another d' \
                            '${TEST_TEMP_DIR}/dir to file/another dir2 folder' \
                            "${READLINE_EXPE}" 38
}
function test_executable_file_completion() {
    guard_interactive_mode || return
    local READLINE_LINE="" READLINE_EXPE=""
    local IFS=$'\n'
    clean_test_dir
    create_test_dir "dir to file"
    create_test_file "dir to file/test.sh"
    chmod +x "${TEST_TEMP_DIR}/dir to file/test.sh"
    echo '#!/usr/bin/env bash' > "${TEST_TEMP_DIR}/dir to file/test.sh"
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='${TEST_TEMP_DIR}/dir\ to\ file/'
    READLINE_EXPE='${TEST_TEMP_DIR}/dir\ to\ file/test.sh'
    assert_bash_completions '${TEST_TEMP_DIR}/dir\ to\ file/' '${TEST_TEMP_DIR}/dir\ to\ file/test.sh' "${READLINE_EXPE}"

    READLINE_LINE='"${TEST_TEMP_DIR}/dir to file/'
    READLINE_EXPE='"${TEST_TEMP_DIR}/dir to file/test.sh'
    assert_bash_completions '${TEST_TEMP_DIR}/dir to file/' '${TEST_TEMP_DIR}/dir to file/test.sh' "${READLINE_EXPE}"
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

function test_redirect_input_output_substitution() {
    local READLINE_LINE="" READLINE_EXPE=""
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='cat some_file > /etc/pass'
    READLINE_EXPE='cat some_file > /etc/passwd'
    assert_bash_completions 'cat some_file > /etc/pass' '/etc/passwd' "${READLINE_EXPE}"

    READLINE_LINE='cat $( echo "$some_file" ) >> /etc/pass'
    READLINE_EXPE='cat $( echo "$some_file" ) >> /etc/passwd'
    assert_bash_completions 'cat $( echo "$some_file" ) >> /etc/pass' '/etc/passwd' "${READLINE_EXPE}"

    _number=10
    READLINE_LINE='bc <<< "5 * $_numb'
    READLINE_EXPE='bc <<< "5 * $_number'
    assert_bash_completions '_numb' '_number' "${READLINE_EXPE}"

    READLINE_LINE='bc <<< "$(hist'
    READLINE_EXPE='bc <<< "$(history'
    assert_bash_completions 'hist' 'history' "${READLINE_EXPE}"
}

function test_logical_cmd_operators() {
    local READLINE_LINE="" READLINE_EXPE=""
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='git status || ech $error_msg'
    READLINE_EXPE='git status || echo $error_msg'
    assert_bash_completions 'ech' 'echo' "${READLINE_EXPE}" 15

    READLINE_LINE='ls .git && git st'
    READLINE_EXPE='ls .git && git status'
    assert_bash_completions 'git st' 'status' "${READLINE_EXPE}"
}

function test_single_quotes() {
    local READLINE_LINE="" READLINE_EXPE=""
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE="echo 'some | git st"
    READLINE_EXPE="echo 'some | git st"
    assert_bash_completions "some | git" '' "${READLINE_EXPE}" 15

    READLINE_LINE="echo 'some | git st"
    READLINE_EXPE="echo 'some | git st"
    assert_bash_completions "some | git st" '' "${READLINE_EXPE}"

    READLINE_LINE="echo '\$(git stat"
    READLINE_EXPE="echo '\$(git stat"
    assert_bash_completions "\$(git stat" '' "${READLINE_EXPE}"
}

function test_double_quotes() {
    local READLINE_LINE="" READLINE_EXPE=""
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE="echo \"some | git st"
    READLINE_EXPE="echo \"some | git st"
    assert_bash_completions "some | git" '' "${READLINE_EXPE}" 15

    READLINE_LINE="echo \"some | git st"
    READLINE_EXPE="echo \"some | git st"
    assert_bash_completions "some | git st" '' "${READLINE_EXPE}"

    READLINE_LINE='echo "$(git stat'
    READLINE_EXPE='echo "$(git status'
    assert_bash_completions "git stat" 'status' "${READLINE_EXPE}"

    READLINE_LINE='echo "hello (world) $BASH_VER'
    READLINE_EXPE='echo "hello (world) $BASH_VERSION'
    assert_bash_completions 'BASH_VER' 'BASH_VERSION' "${READLINE_EXPE}"

    READLINE_LINE='echo "hello (c'
    READLINE_EXPE='echo "hello (c'
    assert_bash_completions 'hello (c' '' "${READLINE_EXPE}"

    READLINE_LINE='echo "bash --version \"${BASH'
    READLINE_EXPE='echo "bash --version \"${BASH_VERSION}'
    assert_bash_completions 'BASH' 'BASH_VERSION' "${READLINE_EXPE}" 28

    READLINE_LINE='echo "bash --version \"'
    READLINE_EXPE='echo "bash --version \"'
    assert_bash_completions 'bash --version \"' '' "${READLINE_EXPE}" 22 'regular_string'

    READLINE_LINE='echo "bash --version "'
    READLINE_EXPE='echo "bash --version "'
    assert_bash_completions 'echo "bash --version "' '' "${READLINE_EXPE}" 22 'cmd'
}

function test_opt_param_assignment() {
    guard_interactive_mode || return
    pushd "${TEST_TEMP_DIR}" &> /dev/null
    local READLINE_LINE="" READLINE_EXPE=""
    local IFS=$'\n' # directories may contain spaces
    create_test_file "input.txt" "output.txt" "extra.txt"
    create_test_dir "spaced dir file/even deeper dir"
    create_test_file "spaced dir file/disk.txt"
    create_test_file "spaced dir file/even deeper dir/here is the file.txt"
    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='dd if='
    READLINE_EXPE='dd if=input.txt'
    assert_bash_completions "dd if=" 'input.txt' "${READLINE_EXPE}"

    READLINE_LINE='dd if=input.txt of='
    READLINE_EXPE='dd if=input.txt of=output.txt'
    assert_bash_completions 'dd if=input.txt of=' 'output.txt' "${READLINE_EXPE}"

    READLINE_LINE='dd if=${TEST_T} of='
    READLINE_EXPE='dd if=${TEST_TEMP_DIR} of='
    assert_bash_completions 'TEST_T' 'TEST_TEMP_DIR' "${READLINE_EXPE}" 13

    READLINE_LINE='dd if=${TEST_TEMP_DIR}/ of='
    READLINE_EXPE='dd if=${TEST_TEMP_DIR}/spaced\ dir\ file of='
    assert_bash_completions 'dd if=${TEST_TEMP_DIR}/' '${TEST_TEMP_DIR}/spaced\ dir\ file' "${READLINE_EXPE}" 22

    READLINE_LINE='dd if=${TEST_TEMP_DIR}/spaced\ dir\ file/ of='
    READLINE_EXPE='dd if=${TEST_TEMP_DIR}/spaced\ dir\ file/disk.txt of='
    assert_bash_completions 'dd if=${TEST_TEMP_DIR}/spaced\ dir\ file/' \
                            '${TEST_TEMP_DIR}/spaced\ dir\ file/disk.txt' "${READLINE_EXPE}" 40

    READLINE_LINE='dd if="${TEST_TEMP_D'
    READLINE_EXPE='dd if="${TEST_TEMP_DIR}'
    assert_bash_completions 'TEST_TEMP_D' 'TEST_TEMP_DIR' "${READLINE_EXPE}" 19

    #                        1         2         3         4         5         6         7         8         9
    #              0123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789
    READLINE_LINE='dd if="${TEST_TEMP_DIR}/ of='
    READLINE_EXPE='dd if="${TEST_TEMP_DIR}/spaced dir file of='
    assert_bash_completions '${TEST_TEMP_DIR}/' \
                            '${TEST_TEMP_DIR}/spaced dir file' "${READLINE_EXPE}" 23

    READLINE_LINE='dd if="${TEST_TEMP_DIR}/spaced dir file/d" of='
    READLINE_EXPE='dd if="${TEST_TEMP_DIR}/spaced dir file/disk.txt" of='
    assert_bash_completions '${TEST_TEMP_DIR}/spaced dir file/d' \
                            '${TEST_TEMP_DIR}/spaced dir file/disk.txt' "${READLINE_EXPE}" 40

    READLINE_LINE='dd if="${TEST_TEMP_DIR}/spaced dir file/even deeper dir/" of=output.xt'
    READLINE_EXPE='dd if="${TEST_TEMP_DIR}/spaced dir file/even deeper dir/here is the file.txt" of=output.xt'
    assert_bash_completions '${TEST_TEMP_DIR}/spaced dir file/even deeper dir/' \
                            '${TEST_TEMP_DIR}/spaced dir file/even deeper dir/here is the file.txt'\
                            "${READLINE_EXPE}" 55

    READLINE_LINE='dd if=${TEST_TEMP_DIR}/spaced\ dir\ file/even\ deeper\ dir/ of=output.xt'
    READLINE_EXPE='dd if=${TEST_TEMP_DIR}/spaced\ dir\ file/even\ deeper\ dir/here\ is\ the\ file.txt of=output.xt'
    assert_bash_completions 'dd if=${TEST_TEMP_DIR}/spaced\ dir\ file/even\ deeper\ dir/' \
                            '${TEST_TEMP_DIR}/spaced\ dir\ file/even\ deeper\ dir/here\ is\ the\ file.txt' \
                            "${READLINE_EXPE}" 58

    popd &> /dev/null
}

function test_cd_completion_with_varname() {
    guard_interactive_mode || return
    clean_test_dir
    create_test_dir 'test_dir'{0..3}
    export TEST_TEMP_DIR
    local -a arr=()
    mapfile -t arr < <(__get_completions 'cd $TEST_TEMP_DIR/')
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
    guard_interactive_mode || return
    clean_test_dir
    create_test_dir 'to_complete'
    local -a arr=()
    mapfile -t arr < <(__get_completions '${TEST_TEMP_DIR}/')
    fwktest_assert_array_contains arr '${TEST_TEMP_DIR}/to_complete'
}
