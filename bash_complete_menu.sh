#!/usr/bin/env bash

__NOCURSOR='\e[?25l'            ## Make cursor invisible
__SHOWCURSOR='\e[?25h'          ## Make cursor visible
__CLEAR_LINE='\e[K'
__CLEAR_2BOTTOM_SCREEN='\e[0J'
__SAVE_CURSOR='\e7'
__RESTORE_CURSOR='\e8'
__INVERT='\e[7m'
__INVERT_BLK='\e[27m'

: "${BASH_COMP_INPUT_TIMEOUT:=0.05}"        # 50ms is enough room to capture special chars on low end PCs

function __get_cursor_position() {
    local -n crow_ref=${1}
    local -n ccol_ref=${2}

    # Save current terminal settings and set raw mode, no echo
    exec 3<&0 < /dev/tty
    local old_stty="$(stty -g)"
    stty raw -echo min 0

    # Request cursor position (ESC[6n)
    printf "\e[6n" > /dev/tty

    # Read the response from the terminal: ESC[row;columnR
    local -a pos=()
    IFS=';' read -d 'R' -ra pos

    # Restore stty input
    exec 0<&3 3<&-

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
    local token=''
    for (( i=0; i<input_len; ++i ))
    do
        for (( ; i<input_len; ++i ))
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
    local -i stack_index=0
    for (( i=0; i<cpos; ++i ))
    do
        local c="${cmdline:${i}:1}"
        local n="${cmdline:$((i+1)):1}"
        if [[ "${c}" == "'" || (${#group_char_stack[@]} -ne 0 &&  "${group_char_stack[-1]}" == "'") ]]
        then
            if [[ ${#group_char_stack[@]} -eq 0 || "${group_char_stack[-1]}" != "'" ]]
            then
                (( ++stack_index ))
                group_char_stack+=( "${c}" )
                continue
            fi

            if [[ "${c}" != "'" ]]
            then
                cmd_stack[${stack_index}]+="${c}"
                continue
            else
                cmd_stack[${stack_index}]+="${c}"
                cmd_stack[stack_index-1]="${cmd_stack[${stack_index}]}${c}"
                unset "cmd_stack[${stack_index}]"
                stack_index=$(( stack_index - 1 ))
                continue
            fi
        elif [[ "${c}" == '\' ]]
        then
            cmd_stack[${stack_index}]+="${c}"
            (( i+1 < cpos )) && (( ++i )) && cmd_stack[${stack_index}]+="${n}"
            continue
        elif [[ "${c}" =~ [\|\;\&] ]]
        then
            # No open group chars means that this an entire new command
            # just separated by a delimiter, this new command will be stored in the next stack's index
            if (( ${#group_char_stack[@]} == 0 ))
            then
                cmd_stack[${stack_index}]+="${c}"
                (( ++stack_index ))
                continue
            fi

            if [[ "${c}" == "${group_char_stack[-1]}" ]]
            then
                cmd_stack[$((stack_index-1))]+="${c}"
                continue
            fi

            if [[ "${group_char_stack[-1]}" != '"' ]]
            then
                cmd_stack[${stack_index}]+="${c}"
                (( ++stack_index ))
                continue
            fi
        elif [[ "${c}" == '$' ]]
        then
            if [[ "${n}" == '(' ]]
            then
                (( ++i ))
                group_char_stack+=( '$(' )
                (( ++stack_index ))
                continue
            elif [[ "${n}" == '{' ]]
            then
                (( ++i ))
                group_char_stack+=( '${' )
                (( ++stack_index ))
                continue
            else
                group_char_stack+=( '$' )
                (( ++stack_index ))
                #continue

                for (( ++i; i<cpos; ++i ))
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
                (( --i ))
                continue
            fi
        elif [[ "${c}" == '<' && "${n}" == '(' ]]
        then
            (( ++i ))
            group_char_stack+=( '<(' )
            (( ++stack_index ))
            continue;
        elif [[ "${c}" == '`' && ( ${#group_char_stack[@]} == 0 || "${group_char_stack[-1]}" != '`' ) ]]
        then
            group_char_stack+=( '`' )
            (( ++stack_index ))
            continue
        elif [[ "${c}" == '"' && ( ${#group_char_stack[@]} == 0 || "${group_char_stack[-1]}" != '"' ) ]]
        then
            group_char_stack+=( '"' )
            (( ++stack_index ))
            continue
        elif [[ "${c}" == '(' && ( ${#group_char_stack[@]} == 0 || "${group_char_stack[-1]}" != ')' ) ]]
        then
            group_char_stack+=( '(' )
            (( ++stack_index ))
            continue
        elif [[ "${c}" =~ [\)\`\}\ \"] && ${#group_char_stack[@]} -gt 0 ]]
        then
            local -A open_close_group_char=( ['$(']=')' ['${']='}' ['(']=')' ['<(']=')' ['`']='`' ['"']='"' ['$']=' ' )
            local open_char="${group_char_stack[-1]}"
            local close_char="${open_close_group_char[${open_char}]}"
            if [[ "${c}" == "${close_char}" ]]
            then
                local -i prev_stack_index=${stack_index}
                (( --stack_index ))
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
            '$')  command_context='var_type2' ;;
            "'")  command_context='literal_string' ;;
            '"')  command_context='regular_string' ;;
            # TODO: ansi_c_string pending to implement
        esac
    fi

    # At char at cursor, if cursor at line_len will append nothing
    cmd_stack[${stack_index}]+=${cmdline:${i}:1}
    command_at_cursor="${cmd_stack[${stack_index}]}"

    local -i is_cursor_mid_line=1
    (( i >= line_len )) && is_cursor_mid_line=0
    command_at_cursor_pos=$(( i - ${#command_at_cursor} + is_cursor_mid_line ))

    # trim leading spaces
    command_at_cursor="${command_at_cursor#"${command_at_cursor%%[![:space:]]*}"}"
    # skip leading spaces
    command_at_cursor_pos+=$(( ${#cmd_stack[${stack_index}]} - ${#command_at_cursor} ))

    [[ "${cmdline:${i}:1}" =~ [\ \(\$\}\)\"\`] ]] && return

    # TODO: optimize this
    for (( ++i; i<line_len; ++i ))
    do
        [[ "${cmdline:${i}:1}" =~ [\ \(\$\}\)\"\`] ]] && break
        command_at_cursor+="${cmdline:${i}:1}"
    done
}

function __get_completions() {
    [[ "${command_context}" == "literal_string" ]] && return

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
    [[ ${COMP_LINE[*]: -1} == ' ' ]] && COMP_WORDS+=('')

    # index of the last word
    COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))

    # main arg usually holds a command, directory or variable
    local main_arg="${COMP_WORDS[0]}"

    # for single/partial cmds queries are done through compgen
    if (( ${#COMP_WORDS[@]} == 0 ))
    then
        COMPREPLY=( "$(compgen -d)" )
    elif (( ${#COMP_WORDS[@]} == 1 ))
    then
        IFS=$'\n' # create arrays using \n as separator
        if [[ "${command_context}" == var_type* ]]
        then
            COMPREPLY=( $(printf '%s\n' "$(compgen -v "${main_arg}")") )
        elif [[ "${main_arg}" =~ ^\$\{?[a-zA-Z_0-9]+$ ]]
        then
            # complete varnames
            local varname="${main_arg##*[$\{]}" # remove unwanted leading chars ${
            COMPREPLY=( $(printf '${%s}\n' "$(compgen -v "${varname}")") )
        elif [[ "${command_context}" == "regular_string" ]]
        then
            # variable with a slash will trigger directory completion
            COMPREPLY=( $(compgen -d "${main_arg}") )
        else
            # compgen -c queries all commands in $PATH and -d directories in $PWD
            COMPREPLY=( $(compgen -d -c "${main_arg}") )
        fi
    elif [[ "${command_context}" == "regular_string" ]]
    then
        COMPREPLY=( "$(compgen -d "${COMP_WORDS[*]}")" )
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
        if [[ -n "${completion}" && "${completion}" != "_comp_complete_minimal" ]]
        then
            # execute completion function
            ${completion} 2> /dev/null
        else
            COMPREPLY=( "$(compgen -f "${COMP_WORDS[*]:1}")" )
        fi
    fi

    if [[ "${command_context}" == "regular_string" ]]
    then
        printf "%s\n" "${COMPREPLY[@]}" | sort -u
    else
        # current command is not quoted ∴ escape spaces
        printf "%s\n" "${COMPREPLY[@]}" | sort -u | sed 's/ \([^ .]\)/\\ \1/g'
    fi
}

function __insert_completion_into_readline() {
    local completion="${complist[${complist_index}]}"
    [[ -z "${completion}" || "${completion}" == '' ]] && return

    local -i i=$((READLINE_POINT-1))
    local -i command_at_cursor_pos_end=$(( command_at_cursor_pos + ${#command_at_cursor} ))

    if [[ "${command_context}" == "regular_string" ]]
    then
        i=command_at_cursor_pos
    fi

    for (( ; i>=command_at_cursor_pos; i-=1 ))
    do
        [[ "${READLINE_LINE:${i}:1}" == " "  && "${READLINE_LINE:$(( i -1 )):1}" != '\' ]] && break
    done

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
    local IFS=
    local key key2
    read -r -s -n 1 key
    # Capture trailing characters (arrow keys/Home/End)
    if [[ "${key}" == $'\e' ]]
    then
        read -r -s -N 2 -t "${BASH_COMP_INPUT_TIMEOUT}" key2
        key+=${key2}
    fi
    case "${key}" in
        $'\e[A') # Move Up
            complist_index=$(( complist_index - num_cols ))
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
            complist_index+=num_cols
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
        $'\e[H') # Home: menu's beginning
            complist_index=0
            ;;
        $'\e[F') # End: menu's end
            complist_index=$(( complist_size - 1))
            ;;
        $'\e') # Quit: ESC
            is_job_done=1
            ;;
        $'\x7f'|$'\b') # backspace
            READLINE_LINE="${READLINE_LINE:0:$((READLINE_POINT-1))}${READLINE_LINE:$((READLINE_POINT))}"
            READLINE_POINT=$(( READLINE_POINT - 1))
            are_completions_updated=0
            if (( READLINE_POINT <= 0 ))
            then
                # we deleted the entire command no need for more completions
                is_job_done=1
            fi
            ;;
        [a-zA-Z0-9_/\.]) # add user input to readline
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
            echo -ne "${__RESTORE_CURSOR}"
            echo -ne "\e[${downward_scrolls}S\e[$(( downward_scrolls ))A"
            echo -e "${__SAVE_CURSOR}"
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
            echo -ne "${__RESTORE_CURSOR}"
            echo -ne "\e[${downward_scrolls}S\e[$(( downward_scrolls ))A"
            echo -e "${__SAVE_CURSOR}"
            crow=$(( crow - downward_scrolls ))
            is_cursor_repositioned=1
        fi
    fi

    local -i i=0 j=0
    for (( i=start_index; i<end_index; i+=num_cols ))
    do
        for (( j=i; j<end_index && j<(i+num_cols); ++j ))
        do
            if (( complist_index == j ))
            then
                printf "${__INVERT}%-$((col_width+cols_padding))s${__INVERT_BLK}" "${complist[j]}"
            else
                printf "%-$((col_width+cols_padding))s" "${complist[j]}"
            fi
        done
        (( j+num_cols > end_index )) && echo -ne "\n${__CLEAR_LINE}" || echo
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
    trap 'trap - SIGINT; is_job_done=1; return' SIGINT

    local -i crow=0 ccol=0
    __get_cursor_position crow ccol

    # Create some space if we're at the very bottom
    # scroll down to create space, them move cursor up
    (( crow == LINES )) && printf "\e[1S\e[1A"

    # Useful margin to manipulate cursor downwards motion (\n or \e[B)
    # as they don't have any affect if bottom lines are already reached
    local -i BOTTOM_PADDING=1
    local -r user_prompt="$( echo -ne "${PS1@P}" | tail -n 1)"

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
    echo -ne "${__NOCURSOR}"
    local IFS=$'\n'
    while (( is_job_done == 0 ))
    do
        if (( ! are_completions_updated ))
        then
            echo -ne "${__CLEAR_LINE}${__CLEAR_2BOTTOM_SCREEN}"

            __get_command_at_cursor "${READLINE_LINE}" ${READLINE_POINT}
            complist=( $(__get_completions "${command_at_cursor}") )
            complist_size=${#complist[@]}
            [[ ${complist_size} == 0 || "${complist[*]}" == "''" ]] && break

            # In a single result case, append it to user input and leave
            if (( complist_size == 1 ))
            then
                __insert_completion_into_readline
                break
            fi

            #__compute_col_width
            col_width=$(printf '%s\n' "${complist[@]}" | wc -L)
            col_width+=2
            are_completions_updated=1
        fi

        echo -e "${__SAVE_CURSOR}${user_prompt}${READLINE_LINE}"
        __print_suggestions
        __input_handling
        echo -ne "${__RESTORE_CURSOR}"
    done
    echo -ne "${__SHOWCURSOR}${__CLEAR_LINE}${__CLEAR_2BOTTOM_SCREEN}"
    IFS=$' \t\n'
    trap - SIGINT
}

