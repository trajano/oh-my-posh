export POSH_THEME=::CONFIG::
export POSH_SHELL_VERSION=$BASH_VERSION
export POWERLINE_COMMAND="oh-my-posh"
export POSH_PID=$$
export CONDA_PROMPT_MODIFIER=false
export OSTYPE=$OSTYPE

if [[ $OSTYPE =~ ^(msys|cygwin) ]]; then
    export POSH_PID=$(command cat /proc/$$/winpid)
fi

# global variables
_omp_start_time=""
_omp_stack_count=0
_omp_elapsed=-1
_omp_no_exit_code="true"
_omp_status_cache=0
_omp_pipestatus_cache=0
_omp_executable=::OMP::

# switches to enable/disable features
_omp_cursor_positioning=0
_omp_ftcs_marks=0

# start timer on command start
PS0='${_omp_start_time:0:$((_omp_start_time="$(_omp_start_timer)",0))}$(_omp_ftcs_command_start)'

# set secondary prompt
_omp_secondary_prompt=$("$_omp_executable" print secondary --shell=bash --shell-version="$BASH_VERSION")

function _omp_set_cursor_position() {
    # not supported in Midnight Commander
    # see https://github.com/JanDeDobbeleer/oh-my-posh/issues/3415
    if [[ $_omp_cursor_positioning == 0 ]] || [[ -v MC_SID ]]; then
        return
    fi

    local oldstty=$(stty -g)
    stty raw -echo min 0

    local COL
    local ROW
    IFS=';' read -rsdR -p $'\E[6n' ROW COL

    stty "$oldstty"

    export POSH_CURSOR_LINE=${ROW#*[}
    export POSH_CURSOR_COLUMN=${COL}
}

function _omp_start_timer() {
    "$_omp_executable" get millis
}

function _omp_ftcs_command_start() {
    if [[ $_omp_ftcs_marks == 1 ]]; then
        printf "\e]133;C\a"
    fi
}

# template function for context loading
function set_poshcontext() {
    return
}

function _omp_print_primary() {
    # Avoid unexpected expansions
    shopt -u promptvars

    local raw_prompt
    if shopt -oq posix; then
        raw_prompt='[NOTICE: Oh My Posh prompt is not supported in POSIX mode]\n\u@\h:\w\$ '
    else
        # Fetch the prompt from Oh My Posh, keeping \[ and \] intact
        raw_prompt=$("$_omp_executable" print primary --shell=bash --shell-version="$BASH_VERSION" \
            --status="$_omp_status_cache" \
            --pipestatus="${_omp_pipestatus_cache[*]}" \
            --execution-time="$_omp_elapsed" \
            --stack-count="$_omp_stack_count" \
            --no-status="$_omp_no_exit_code" \
            --terminal-width="${COLUMNS-0}" | tr -d '\0')
    fi

    # Output the raw prompt with \[ and \] intact
    echo "$raw_prompt"
}

function _omp_print_secondary() {
    # Avoid unexpected expansions
    shopt -u promptvars

    local raw_prompt
    if shopt -oq posix; then
        raw_prompt='> '
    else
        raw_prompt="$_omp_secondary_prompt"
    fi

    # Output the raw prompt with \[ and \] intact
    echo "$raw_prompt"
}
function _omp_hook() {
    _omp_status_cache=$?
    _omp_pipestatus_cache=("${PIPESTATUS[@]}")

    if [[ ${#BP_PIPESTATUS[@]} -ge ${#_omp_pipestatus_cache[@]} ]]; then
        _omp_pipestatus_cache=("${BP_PIPESTATUS[@]}")
    fi

    _omp_stack_count=$((${#DIRSTACK[@]} - 1))

    if [[ $_omp_start_time ]]; then
        local omp_now=$("$_omp_executable" get millis --shell=bash)
        _omp_elapsed=$((omp_now - $_omp_start_time))
        _omp_start_time=""
        _omp_no_exit_code="false"
    fi

    if [[ ${_omp_pipestatus_cache[-1]} != "$_omp_status_cache" ]]; then
        _omp_pipestatus_cache=("$_omp_status_cache")
    fi

    set_poshcontext
    _omp_set_cursor_position

    # Capture the primary prompt and escape backslashes unless they are followed by [ or ]
    local primary_prompt="$(_omp_print_primary)"
    local safe_primary_prompt=$(echo "$primary_prompt" | sed 's/\\\([^\[\]]\)/\\\\\1/g')

    PS1="$safe_primary_prompt"

    # Capture the secondary prompt and escape backslashes unless they are followed by [ or ]
    local secondary_prompt="$(_omp_print_secondary)"
    local safe_secondary_prompt=$(echo "$secondary_prompt" | sed 's/\\\([^\[\]]\)/\\\\\1/g')

    PS2="$safe_secondary_prompt"

    return $_omp_status_cache
}

function _omp_install_hook() {
    [[ $TERM = linux ]] && return

    local cmd
    for cmd in "${PROMPT_COMMAND[@]}"; do
        if [[ $cmd = "_omp_hook" ]]; then
            return
        fi
    done
    PROMPT_COMMAND=(_omp_hook "${PROMPT_COMMAND[@]}")
}

_omp_install_hook
