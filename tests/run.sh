#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DT="$ROOT/dt"
TMP_ROOT="${TMPDIR:-/tmp}"
TMP_ROOT="${TMP_ROOT%/}"
TMP_PARENT="$(mktemp -d "$TMP_ROOT/dt-tests.XXXXXX")"
TEST_HOME=""

new_home() {
    local dir

    dir="$(mktemp -d "$TMP_PARENT/home.XXXXXX")"
    printf '%s\n' "$dir"
}

cleanup() {
    rm -rf "$TMP_PARENT"
}

trap cleanup EXIT

run_dt() {
    HOME="$TEST_HOME" "$DT" "$@"
}

run_dt_with_config_home() {
    HOME="$TEST_HOME/home" XDG_CONFIG_HOME="$TEST_HOME/config" "$DT" "$@"
}

assert_eq() {
    local name="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" != "$expected" ]]; then
        printf 'not ok - %s\n' "$name" >&2
        printf 'expected:\n%s\n' "$expected" >&2
        printf 'actual:\n%s\n' "$actual" >&2
        exit 1
    fi
}

expect_fail() {
    local name="$1"
    shift
    local output
    local status

    set +e
    output="$(run_dt "$@" 2>&1)"
    status="$?"
    set -e

    if [[ "$status" -eq 0 ]]; then
        printf 'not ok - %s\nexpected failure, got success:\n%s\n' "$name" "$output" >&2
        exit 1
    fi
}

test_help() {
    local actual

    actual="$(run_dt help)"
    assert_eq "help includes heads" "  heads    display tops of all stacks" "$(printf '%s\n' "$actual" | grep 'heads')"
}

test_empty_stack() {
    local actual

    actual="$(run_dt)"
    assert_eq "empty stack head" "*" "$actual"

    actual="$(run_dt cat)"
    assert_eq "empty stack cat" $'-- main --\n*' "$actual"
}

test_push_pop_and_yank() {
    local actual

    run_dt push first
    run_dt push second

    actual="$(run_dt cat)"
    assert_eq "cat displays newest first" $'-- main --\n* second\nfirst' "$actual"

    run_dt pop
    actual="$(run_dt)"
    assert_eq "pop removes newest item" "* first" "$actual"

    run_dt push
    actual="$(run_dt)"
    assert_eq "push with no args restores last popped item" "* second" "$actual"
}

test_missing_yank_does_not_push_blank() {
    local actual

    expect_fail "push without item or yank fails" push
    actual="$(run_dt cat)"
    assert_eq "failed push leaves stack empty" $'-- main --\n*' "$actual"
}

test_stack_names_are_restricted() {
    expect_fail "switch rejects spaces" switch "two words"
    expect_fail "switch rejects path traversal" switch "../outside"
    expect_fail "switch rejects leading hyphen" switch "-option"
}

test_invalid_stack_files_are_ignored() {
    local actual

    run_dt ls >/dev/null
    printf 'legacy\n' > "$TEST_HOME/.config/distracked/two words"

    actual="$(run_dt ls)"
    assert_eq "invalid stack files are ignored" "* main" "$actual"
}

test_xdg_config_home_is_used() {
    local actual

    run_dt_with_config_home push xdg-task

    actual="$(cat "$TEST_HOME/config/distracked/main")"
    assert_eq "XDG_CONFIG_HOME stores stacks" "xdg-task" "$actual"

    if [[ -e "$TEST_HOME/home/.config/distracked" ]]; then
        printf 'not ok - XDG_CONFIG_HOME bypasses HOME/.config\n' >&2
        exit 1
    fi
}

test_switch_ls_all_and_heads() {
    local actual

    run_dt push main-task
    run_dt switch side >/dev/null
    run_dt push side-task

    actual="$(run_dt ls)"
    assert_eq "ls marks current stack first" $'* side\nmain' "$actual"

    actual="$(run_dt all)"
    assert_eq "all displays current stack first" $'-- side --\n* side-task\n\n-- main --\n* main-task' "$actual"

    actual="$(run_dt heads)"
    assert_eq "heads displays stack tops" $'-- side --\n* side-task\n\n-- main --\n* main-task' "$actual"
}

test_rm_keeps_main_and_preserves_bak_stack() {
    local actual

    run_dt switch foo >/dev/null
    run_dt push foo-task
    run_dt switch notes.bak >/dev/null
    run_dt push keep-me
    run_dt switch foo >/dev/null
    run_dt pop

    actual="$(run_dt ls)"
    assert_eq "pop does not remove .bak-named stack" $'* foo\nmain\nnotes.bak' "$actual"

    run_dt switch main >/dev/null
    run_dt rm foo
    actual="$(run_dt ls)"
    assert_eq "rm removes requested non-main stack" $'* main\nnotes.bak' "$actual"

    expect_fail "rm refuses main stack" rm main
}

run_test() {
    local name="$1"
    shift

    TEST_HOME="$(new_home)"
    "$@"
    printf 'ok - %s\n' "$name"
}

run_test "help" test_help
run_test "empty stack" test_empty_stack
run_test "push pop and yank" test_push_pop_and_yank
run_test "missing yank" test_missing_yank_does_not_push_blank
run_test "restricted stack names" test_stack_names_are_restricted
run_test "invalid stack files ignored" test_invalid_stack_files_are_ignored
run_test "XDG_CONFIG_HOME" test_xdg_config_home_is_used
run_test "switch ls all and heads" test_switch_ls_all_and_heads
run_test "rm and backup safety" test_rm_keeps_main_and_preserves_bak_stack
