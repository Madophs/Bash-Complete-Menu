#!/usr/bin/env bash

__NOCURSOR='\e[?25l'           ## Make cursor invisible
__SHOWCURSOR='\e[?25h'           ## Make cursor visible
__CLEAR_LINE='\e[K'
__CLEAR_2BOTTOM_SCREEN='\e[0J'
__SAVE_CURSOR='\e7'
__RESTORE_CURSOR='\e8'

function __get_cursor_position() {
    local -n crow_ref=${1}
    local -n ccol_ref=${2}

    # Save current terminal settings and set raw mode, no echo
    exec < /dev/tty
    local old_stty=$(stty -g)
    stty raw -echo min 0

    # Request cursor position (ESC[6n)
    printf "\e[6n" > /dev/tty

    # Read the response from the terminal: ESC[row;columnR
    local -a pos=()
    IFS=';' read -ra pos -d R

    # Restore terminal settings
    stty "${old_stty}"

    # Extract row and column, adjusting for 0-based indexing if needed (terminal is 1-based)
    crow_ref=${pos[0]:2} # Strip the leading "ESC["
    ccol_ref=${pos[1]}
}

function __parse_comp_input() {
    local -n comp_words_ptr=${1}
    shift
    local raw_input="${*}"
    local -i input_len=${#raw_input}
    local -i is_escaped_char=0
    local l='' token=''
    for (( i=0; i<input_len; i+=1 ))
    do
        for (( ; i<input_len; i+=1 ))
        do
            [[ "${raw_input:${i}:1}" == ' ' && ${is_escaped_char} == 0 ]] && break

            token+="${raw_input:${i}:1}"

            if [[ ${is_escaped_char} == 1 ]]
            then
                is_escaped_char=0
            elif [[ "${raw_input:${i}:1}" == '\' ]]
            then
                is_escaped_char=1 # Next character most be escaped
            fi
        done
        [[ -n "${token}" ]] && comp_words_ptr+=( "${token}" )
        token=''
    done
}

function __get_command_at_cursor() {
    local cmdline="${1}"
    local -i line_len=${#cmdline}
    local -i cpos=${2:-line_len}
    local -a group_char_stack=()
    local -A cmd_stack=()
    command_at_cursor=""
    command_context='cmd'

    # opening cmdline arguments ⮞ $(,(,$((,((,$,${,<(,${ ,`,",
    # cmdline separators arguments ⮞ |,;,<,>,

    local -i i=0
    local -i cmd_base=0
    local -i stack_index=0
    for (( i=0; i<cpos; i+=1 ))
    do
        local c="${cmdline:${i}:1}"
        local n="${cmdline:$((i+1)):1}"
        if [[ "${c}" == '\' ]]
        then
            cmd_stack[${stack_index}]+="${c}"
            cmd_stack[${stack_index}]+="${n}"
            i+=1
            continue
        elif [[ "${c}" =~ [\|]|[\;] ]]
        then
            # No open group chars means that this an entire new command
            # just separated by a delimiter, this new command will be stored in the next stack's index
            if (( ${#group_char_stack[@]} == 0 ))
            then
                cmd_stack[${stack_index}]+="${c}"
                stack_index+=1
                continue
            fi

            # Open groups chars ⟦$(,<(,`⟧ indicates that this is a subcommand
            # separated a by a delimiter ∴ will be treated as such
            if [[ "${group_char_stack[-1]}" =~ [$][\(]|[\<][\(]|[\`] ]]
            then
                cmd_stack[${stack_index}]+="${c}"
                stack_index+=1
                continue
            fi
        elif [[ "${c}" =~ [$] ]]
        then
            if [[ "${n}" == '(' ]]
            then
                i+=1
                group_char_stack+=( '$(' )
                stack_index+=1
                continue
            elif [[ "${n}" == '{' ]]
            then
                i+=1
                group_char_stack+=( '${' )
                stack_index+=1
                continue
            else
                group_char_stack+=( '$' )
                stack_index+=1
                #continue

                for (( i+=1; i<cpos; i+=1 ))
                do
                    [[ "${cmdline:${i}:1}" =~ [a-zA-Z_] ]] || break
                    cmd_stack[${stack_index}]+="${cmdline:${i}:1}"
                done

                # There's no need for iteration this variable is at the end
                (( i >= cpos )) && break

                local -i prev_stack_index=${stack_index}
                stack_index=$(( stack_index - 1 ))
                local open_char='$'
                cmd_stack[${stack_index}]+="${open_char}${cmd_stack[${prev_stack_index}]}"
                unset 'group_char_stack[-1]'
                unset "cmd_stack[${prev_stack_index}]"

                # We must continue in the current position on next iteration
                i=$(( i - 1 ))
                continue
            fi
        elif [[ "${c}" == '<' && "${n}" == '(' ]]
        then
            i+=1
            group_char_stack+=( '<(' )
            stack_index+=1
            continue;
        elif [[ "${c}" == '`' && ( ${#group_char_stack[@]} == 0 || "${group_char_stack[-1]}" != '`' ) ]]
        then
            group_char_stack+=( '`' )
            stack_index+=1
            continue
        #elif [[ "${c}" == '"' && ( ${#group_char_stack[@]} == 0 || "${group_char_stack[-1]}" != '"' ) ]]
        #then
            #group_char_stack+=( '"' )
            #stack_index+=1
            #continue
        elif [[ "${c}" == '(' && ( ${#group_char_stack[@]} == 0 || "${group_char_stack[-1]}" != ')' ) ]]
        then
            group_char_stack+=( '(' )
            stack_index+=1
            continue
        elif [[ "${c}" =~ [\)\`\}\ ] && ${#group_char_stack[@]} -gt 0 ]]
        then
            local -A open_close_group_char=( ['$(']=')' ['${']='}' ['(']=')' ['<(']=')' ['`']='`' ['"']='"' ['$']=' ' )
            local open_char="${group_char_stack[-1]}"
            local close_char="${open_close_group_char[${open_char}]}"
            if [[ "${c}" == "${close_char}" ]]
            then
                local -i prev_stack_index=${stack_index}
                stack_index=$(( stack_index - 1 ))
                cmd_stack[${stack_index}]+="${open_char}${cmd_stack[${prev_stack_index}]}${close_char}"

                unset 'group_char_stack[-1]'
                unset "cmd_stack[${prev_stack_index}]"
                continue
            fi
        fi

        cmd_stack[${stack_index}]+="${c}"
    done

    #for key in "${!cmd_stack[@]}"
    #do
        #echo "${key} ⮞ ${cmd_stack[${key}]}"
    #done

    if (( ${#group_char_stack[@]} > 0 ))
    then
        case "${group_char_stack[-1]}" in
            '${') command_context='var_type1' ;;
            '$') command_context='var_type2' ;;
        esac
    fi

    # At char at cursor, if cursor at line_len will append nothing
    cmd_stack[${stack_index}]+=${cmdline:${i}:1}
    command_at_cursor="${cmd_stack[${stack_index}]}"

    local -i is_cursor_mid_line=1
    (( i >= line_len )) && is_cursor_mid_line=0
    command_at_cursor_pos=$(( i - ${#command_at_cursor} + ${is_cursor_mid_line} ))

    # trim leading spaces
    command_at_cursor="${command_at_cursor#${command_at_cursor%%[![:space:]]*}}"
    local -i leading_spaces_count=$(( ${#cmd_stack[${stack_index}]} - ${#command_at_cursor} ))
    command_at_cursor_pos+=leading_spaces_count

    [[ "${cmdline:${i}:1}" =~ [\ \(\$\}\)\"\`] ]] && return

    for (( i+=1; i<line_len; i+=1 ))
    do
        [[ "${cmdline:${i}:1}" =~ [\ \(\$\}\)\"\`] ]] && break
        command_at_cursor+="${cmdline:${i}:1}"
    done
}

function __get_completions() {
    local IFS=$' \t\n'
    local completion COMP_CWORD COMP_LINE COMP_POINT COMP_WORDS COMPREPLY=()

    #load bash-completion if necessary
    declare -F _completion_loader &>/dev/null || {
        source /usr/share/bash-completion/bash_completion
    }

    COMP_LINE="${*}"
    COMP_POINT=${#COMP_LINE}

    __parse_comp_input COMP_WORDS "${COMP_LINE}"

    # add '' to COMP_WORDS if the last character of the command line is a space
    [[ ${COMP_LINE[@]: -1} = ' ' ]] && COMP_WORDS+=('')

    # index of the last word
    COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))

    # main arg usually holds a command, directory or variable
    local main_arg="${COMP_WORDS[0]}"

    # for single/partial cmds queries are done through compgen
    if (( ${#COMP_WORDS[@]} == 1 ))
    then
        IFS=$'\n' # create arrays using \n as separator
        if [[ "${command_context}" == var_type* ]]
        then
            COMPREPLY=( $(printf '%s\n' $(compgen -v "${main_arg}")) )
        elif [[ "${main_arg}" =~ ^\$\{?[a-zA-Z_0-9]+$ ]]
        then
            # complete varnames
            local varname="${main_arg##*[$\{]}" # remove unwanted leading chars ${
            COMPREPLY=( $(printf '${%s}\n' $(compgen -v "${varname}")) )
        elif [[ "${main_arg}" =~ ^\$\{?[a-zA-Z_0-9]+\}?\/$ ]]
        then
            # variable with a slash will trigger directory completion
            COMPREPLY=( $(compgen -d "${main_arg}") )
        else
            # compgen -c queries all commands in $PATH and -d directories in $PWD
            COMPREPLY=( $(compgen -d -c "${main_arg}") )
        fi
    else
        # determine completion function
        completion=$(complete -p "${main_arg}" 2>/dev/null | awk '{print $(NF-1)}')

        # run _completion_loader only if necessary
        if [[ -z ${completion} ]]
        then
            # load completion
            _completion_loader "${main_arg}"

            # detect completion
            completion=$(complete -p "${main_arg}" 2>/dev/null | awk '{print $(NF-1)}')
        fi

        # ensure completion was detected
        [[ -n ${completion} ]] || return 1

        # execute completion function
        ${completion} 2> /dev/null
    fi

    IFS=$'\n'
    COMPREPLY=( $(printf "%s\n" "${COMPREPLY[@]}" | sort -u) )

    # print completions to stdout
    local comp
    for comp in "${COMPREPLY[@]}"
    do
        if [[ "${comp: -1}" == " " ]]
        then
            comp="${comp:0: -1}"
            printf '%s\n' "${comp// /\\ } "
        else
            printf '%s\n' "${comp// /\\ }"
        fi
    done
}

function __insert_completion_into_readline() {
    for (( i=$((READLINE_POINT-1)); i>=command_at_cursor_pos; i-=1 ))
    do
        [[ "${READLINE_LINE:${i}:1}" == " "  && "${READLINE_LINE:$(( i -1 )):1}" != '\' ]] && break
    done

    local completion="${complist[${complist_index}]}"
    local -i command_at_cursor_pos_end=$(( command_at_cursor_pos + ${#command_at_cursor} ))
    if [[ "${command_context}" == "var_type1" && "${READLINE_LINE:${command_at_cursor_pos_end}:1}" != '}' ]]
    then
        completion+="}"
    fi
    READLINE_LINE="${READLINE_LINE:0:$((i+1))}${completion}${READLINE_LINE:${command_at_cursor_pos_end}}"
    READLINE_POINT=$(( i + 1 + ${#completion} ))
    is_job_done=1
}

function __input_handling() {
    # Read a single character
    IFS= read -s -n 1 key
    # Capture trailing characters
    read -s -N 1 -t 0.0001 k1
    read -s -N 1 -t 0.0001 k2
    read -s -N 1 -t 0.0001 k3
    key+=${k1}${k2}${k3}
    case "${key}" in
        $'\e[A') # Move Up
            case "${key}" in
                u*) complist_index=$(( complist_index - (num_cols * scroll_slice) )) ;;
                *) complist_index=$(( complist_index - num_cols )) ;;
            esac

            if (( complist_index < 0 ))
            then
                complist_index+=num_cols
                local -i rem=$(( complist_index % num_cols ))
                complist_index=$(( num_cols * num_rows + rem ))
                while (( complist_index >= complist_size ))
                do
                    complist_index=$(( complist_index - num_cols ))
                done
            fi
            ;;
        $'\e[B') # Move Down: down arrow
            case "${key}" in
                d*) complist_index+=$(( num_cols * scroll_slice )) ;;
                *) complist_index+=num_cols ;;
            esac

            if (( complist_index >= complist_size ))
            then
                complist_index=$(( complist_index % num_cols ))
            fi
            ;;
        $'\e[D'|$'\e[Z') # Move left: <-,left-tab
            complist_index=$(( complist_index - 1 ))
            (( complist_index < 0 )) && complist_index=$(( complist_size - 1 ))
            ;;
        $'\e[C'|$'\t') # Move right: <-,tab
            complist_index=$(( (complist_index + 1) % complist_size ))
            ;;
        $'\e[H') # Go to menu's first item
            complist_index=0
            ;;
        $'\e[F') # Move to last item
            complist_index=$(( complist_size - 1))
            ;;
        $'') # Quit: ESC
            is_job_done=1
            ;;
        $'\x7f') # backspace
            READLINE_LINE="${READLINE_LINE:0:$((READLINE_POINT-1))}${READLINE_LINE:$((READLINE_POINT+1))}"
            READLINE_POINT=$(( READLINE_POINT - 1))
            are_completions_updated=0
            ;;
        [a-zA-Z0-9_\/\.]) # add user input to readline
            READLINE_LINE="${READLINE_LINE:0:${READLINE_POINT}}${key}${READLINE_LINE:${READLINE_POINT}}"
            READLINE_POINT=$(( READLINE_POINT + 1))
            are_completions_updated=0
            ;;
        ""|' ')
            __insert_completion_into_readline
            ;;
    esac
}

function __print_suggestions() {
    num_cols=$(( COLUMNS / col_width ))
    num_rows=$(( complist_size / num_cols ))
    scroll_slice=$(( num_rows / 2 ))
    (( (complist_size % num_cols) != 0 )) && num_rows+=1 # Round up
    local -i cols_padding=$(( (COLUMNS % col_width) / num_cols )) # space between cols
    local -i avail_lines=$(( LINES - BOTTOM_PADDING - crow ))

    end_index=$(( num_rows * num_cols ))
    (( end_index > complist_size )) && end_index=complist_size

    if (( num_rows > (LINES - BOTTOM_PADDING) ))
    then
        local -i scroll_window_size=$(( LINES - BOTTOM_PADDING - 2 ))
        local -i current_row=$(( complist_index / num_cols ))

        # upper/lower item padding
        scroll_slice=$(( scroll_window_size / 2 ))

        local -i row_index=0
        # update row if position is beyond scroll slice (upper bound)
        (( current_row - scroll_slice > 0 )) && row_index=$(( current_row - scroll_slice ))

        end_index=$(( (row_index + scroll_window_size) * num_cols ))
        start_index=$(( row_index * num_cols ))

        # Print all possible items above index in case we're near the list's end (bottom)
        (( end_index > complist_size )) && start_index=$(( (num_rows - scroll_window_size) * num_cols ))
        (( end_index > complist_size )) && end_index=$(( complist_size ))

        if (( is_cursor_repositioned == 0 && crow > 1 ))
        then
            local -i downward_scrolls=$(( crow - 1 ))
            printf "${__RESTORE_CURSOR}"
            printf "\e[${downward_scrolls}S\e[$(( downward_scrolls ))A"
            printf "${__SAVE_CURSOR}\n"
            crow=1
            is_cursor_repositioned=1
        fi
    else
        # if there's no space to print, then we will scroll and reposition
        if (( avail_lines < num_rows && is_cursor_repositioned == 0 ))
        then
            if (( avail_lines > 0 ))
            then
                local -i downward_scrolls=$(( num_rows - avail_lines ))
            else
                local -i downward_scrolls=$(( num_rows + BOTTOM_PADDING ))
            fi
            printf "${__RESTORE_CURSOR}"
            printf "\e[${downward_scrolls}S\e[$(( downward_scrolls ))A"
            printf "${__SAVE_CURSOR}\n"
            crow=$(( crow - downward_scrolls ))
            is_cursor_repositioned=1
        fi
    fi

    for (( i=start_index; i<end_index; i+=num_cols ))
    do
        for (( j=i; j<end_index && j<(i+num_cols); j+=1 ))
        do
            if (( complist_index == j ))
            then
                printf "${INVERT}%-$(( (col_width+cols_padding) ))s${INVERT_BLK}" ${complist[j]}
            else
                printf "%-$(( (col_width+cols_padding) ))s" ${complist[j]}
            fi
        done
        (( j+num_cols > end_index )) && printf "\n${__CLEAR_LINE}" || echo
    done
}

function __compute_col_width() {
    col_width=0
    for item in "${complist[@]}"
    do
        if (( col_width < (${#item}+2) ))
        then
            col_width=$(( ${#item} + 2 )) # 2 columns for padding
        fi
    done
}

function bash_complete_menu() {
    local -i crow=0 ccol=0
    __get_cursor_position crow ccol

    # Create some space if we're at the very bottom
    # scroll down to create space, them move cursor up
    (( crow == LINES )) && printf "\e[1S\e[1A"

    # Useful margin to manipulate cursor downwards motion (\n or \e[B)
    # as they don't have any affect if bottom lines are already reached
    local  -i BOTTOM_PADDING=1
    local __user_prompt="$( printf "${PS1@P}" | tail -n 1)"

    local -i complist_size=0
    local -i start_index=0 end_index=0
    local -i num_rows=0 num_cols=0 col_width=0
    local -i scroll_slice=0

    # cursor reposition only need once if required
    local -i is_cursor_repositioned=0
    local -i complist_index=0
    local -i is_job_done=0

    local -i are_completions_updated=0
    local command_at_cursor="" command_context=""
    local -i command_at_cursor_pos=0
    local -a complist=()
    printf "${__NOCURSOR}"
    while (( is_job_done == 0 ))
    do
        if (( ! are_completions_updated ))
        then
            printf "${__CLEAR_LINE}${__CLEAR_2BOTTOM_SCREEN}"

            local IFS=$'\n'
            __get_command_at_cursor "${READLINE_LINE}" ${READLINE_POINT}
            complist=( $(__get_completions "${command_at_cursor}" ))
            complist_size=${#complist[@]}
            [[ ${complist_size} == 0 || "${complist[@]}" == "''" ]] && break

            # In a single result case, append it to user input and leave
            if (( complist_size == 1 ))
            then
                __insert_completion_into_readline
                break
            fi

            __compute_col_width
            are_completions_updated=1
        fi

        printf "${__SAVE_CURSOR}${__user_prompt}${READLINE_LINE}\n"
        __print_suggestions
        __input_handling
        printf "${__RESTORE_CURSOR}"
    done
    printf "${__SHOWCURSOR}${__CLEAR_LINE}${__CLEAR_2BOTTOM_SCREEN}"
}

