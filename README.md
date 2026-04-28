# dt

`dt` is a small macOS productivity tool that organizes work into named LIFO
stacks. It stores stacks as plain text files in
`${XDG_CONFIG_HOME:-$HOME/.config}/distracked`.

## Usage

```console
$ ./dt help
usage: ./dt [subcmd]
  subcmd:  behavior:
  all      display entire contents of all stacks
  cat      display entire contents of current stack
  edit     open all stacks in text editor for bulk modification
  head     display top of current stack
  heads    display tops of all stacks
  help     display this message
  ls       list all stacks
  pop      remove top of current stack
  push     add item at top of current stack
  rm       delete given stack
  switch   switch to given stack, creating it if necessary
```

Running `dt` for the first time creates an empty `main` stack.

```console
$ ./dt ls
* main

$ ./dt
*
```

Push work items onto the current stack. The newest item is shown first.

```console
$ ./dt push Upload dt to GitHub
$ ./dt push Write a readme for dt
$ ./dt push Record a screencast for dt

$ ./dt cat
-- main --
* Record a screencast for dt
Write a readme for dt
Upload dt to GitHub
```

Switch stacks when an interruption needs its own context.

```console
$ ./dt switch interrupted-by-boss
* interrupted-by-boss
main

$ ./dt push Work on important project
$ ./dt push Go to important meeting

$ ./dt all
-- interrupted-by-boss --
* Go to important meeting
Work on important project

-- main --
* Record a screencast for dt
Write a readme for dt
Upload dt to GitHub
```

Pop completed work. Running `push` with no arguments restores the last popped
item.

```console
$ ./dt pop

$ ./dt
* Work on important project

$ ./dt pop
$ ./dt push

$ ./dt
* Work on important project
```

When a stack is no longer needed, remove it.

```console
$ ./dt switch main
* main
interrupted-by-boss

$ ./dt rm interrupted-by-boss
```

Stack names may contain letters, numbers, dots, underscores, and hyphens. They
must not start with a dot or hyphen.

`dt` can be run from any directory once it is on your `PATH`; it stores and
loads data from its config directory, not from the current working directory.
For one-off testing, set `DISTRACKED_DIR` to point at a temporary directory.

## Development

Run the test suite with:

```console
$ ./tests/run.sh
```
