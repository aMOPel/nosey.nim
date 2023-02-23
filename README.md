# nosey.nim
A minimal file watcher library,
specialized on applying a state to a directory based on another directory.

It uses hashes of file contents to determine changes.
This is far **less efficient** and **less versatile**,
compared to an OS-event-based approach, 
like [libfswatch](https://github.com/paul-nameless/nim-fswatch),
but this library is **free of dependencies** outside the nim stdlib.

## Usage
```nim
const
  sourceDir = "source"
  targetDir = "target"
  jsonFile = "dirState.json"

watch(
  sourceDir, # the source directory to watch
  targetDir, # the target directory to write to
  5000, # the interval in milliseconds after which to rescan the sourceDir
  defaultChangedFileHandler, # called on every NEW file in sourceDir
  defaultChangedFileHandler, # called on every CHANGED file in sourceDir
  defaultDeletedFileHandler, # called on every DELETED file in sourceDir
  # the `watch` proc itself doesn't do any file mutation,
  # it just calls the above callbacks
  jsonFile # optional json file, that holds dirState between sessions
)

# or

runOnce(
  sourceDir, # the source directory to watch
  targetDir, # the target directory to write to
  defaultChangedFileHandler, # called on every NEW file in sourceDir
  defaultChangedFileHandler, # called on every CHANGED file in sourceDir
  defaultDeletedFileHandler, # called on every DELETED file in sourceDir
  # the `watch` proc itself doesn't do any file mutation,
  # it just calls the above callbacks
  jsonFile # optional json file, that holds dirState between sessions
)

# alternatively you can pass a DirState instead of a json file name to 
# supply the initial DirState
```

You can also write your own `watch` proc,
using the other utilities in this library.

Generate full documentation with:
```sh
nim doc --project ./src/nosey.nim
```

