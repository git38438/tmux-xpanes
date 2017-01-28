#!/bin/bash

# Directory name of this file
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")"; pwd)"

BIN_DIR="${THIS_DIR}/../"
# Get repository name which equals to bin name.
# BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
BIN_NAME="xpanes"
EXEC="./${BIN_NAME}"


_socket="${TMPDIR}/shunit.session"
_session_name="shunit_session"
_window_name="shunit_window"

create_tmux_session(){
    # echo "tmux kill-session -t $_session_name 2> /dev/null"
    tmux kill-session -t $_session_name 2> /dev/null

    # echo "rm -f ${TMPDIR}/shunit.session"
    rm -f ${TMPDIR}/shunit.session

    # echo "tmux new-session -s $_session_name -n $_window_name -d"
    tmux new-session -s $_session_name -n $_window_name -d
}

exec_in_tmux_session(){
    # echo "tmux send-keys -t $_session_name:$_window_name \"cd ${BIN_DIR} && $*; touch ${TMPDIR}/done\" C-m" >&2
    tmux send-keys -t $_session_name:$_window_name "cd ${BIN_DIR} && $*; touch ${TMPDIR}/done" C-m

    # Wait until tmux session is completely established.
    for i in $(seq 100) ;do
        sleep 1
        if [ -e "${TMPDIR}/done" ]; then
            rm -f "${TMPDIR}/done"
            break
        fi
        # Tmux session does not work.
        if [ $i -eq 100 ]; then
            echo "Test failed" >&2
            return 1
        fi
    done

    # echo "tmux capture-pane -t $_session_name:$_window_name" >&2
    tmux capture-pane -t $_session_name:$_window_name

    # Show result
    # echo "tmux show-buffer | awk NF" >&2
    tmux show-buffer | awk NF
    return 0
}

setUp(){
    cd ${BIN_DIR}
    # create_tmux_session
}

kill_tmux_session(){
    tmux kill-session -t $_session_name
    rm -f ${TMPDIR}/shunit.session
}

# tearDown() {
#     kill_tmux_session
# }

test_version() {
    #
    # From out side of TMUX session
    #
    cmd="${EXEC} -V"; result=$($cmd); echo $cmd
    echo ${result} | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"

    cmd="${EXEC} --version"; result=$($cmd); echo $cmd
    echo ${result} | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"

    #
    # From in side of TMUX session
    #
    create_tmux_session
    cmd="exec_in_tmux_session ${EXEC} -V"; result=$($cmd); echo $cmd
    echo ${result} | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"
    kill_tmux_session

    create_tmux_session
    cmd="exec_in_tmux_session ${EXEC} --version"; result=$($cmd); echo $cmd
    echo ${result} | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"
    kill_tmux_session
}

test_help() {
    cmd="${EXEC} -h"; result=$($cmd); echo $cmd
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"

    cmd="${EXEC} --help"; result=$($cmd); echo $cmd
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"

    create_tmux_session
    cmd="exec_in_tmux_session ${EXEC} -h"; result=$($cmd); echo $cmd
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"
    kill_tmux_session

    create_tmux_session
    cmd="exec_in_tmux_session ${EXEC} --help"; result=$($cmd); echo $cmd
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"
    kill_tmux_session
}

test_devide_two_panes() {
    ${EXEC} --no-attach XPANES BBBB
    window_name=$(tmux list-windows -F '#{window_name}' | grep 'XPANES' | head -n 1)

    echo "Check number of windows"
    assertEquals 2 "$(tmux list-windows -t "$window_name" | grep -c .)"

    echo "Check width -- A:$a_width B:$b_width"
    a_width=$(tmux list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==2')
    # true:1, false:0
    # a_width +- 1 is b_width
    assertEquals 1 "$(( ( $a_width + 1 ) == $b_width || $a_width == $b_width || ( $a_width - 1 ) == $b_width ))"

    a_height=$(tmux list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==2')
    echo "Check height -- A:$a_height B:$b_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
    tmux kill-window -t $window_name
}

. ${THIS_DIR}/shunit2/source/2.1/src/shunit2
