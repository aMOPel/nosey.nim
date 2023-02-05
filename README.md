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

proc defaultFileConverter*(sourceFilePath, targetDir: string) =
  ## the default fileConverter
  ## it simply copies the file to targetDir
  copyFileToDir(sourceFilePath, targetDir)

proc defaultFileRemover*(sourceFilePath, targetDir: string) =
  ## the default fileRemover
  ## it simply removes the file from targetDir
  removeFile(targetDir/sourceFilePath.splitPath.tail)

watch(
  sourceDir, # the source directory to watch
  targetDir, # the target directory to write to
  5000, # the interval in milliseconds after which to rescan the sourceDir
  defaultFileConverter, # called on every change in sourceDir
  defaultFileRemover, # called on every delete in sourceDir
  # the `watch` proc itself doesn't do any file mutation,
  # it just calls the above callbacks
  jsonFile # optional json file, that holds dirState between sessions
)
```

You can also write your own `watch` proc,
using the other utilities in this library.

Generate full documentation with:
```sh
nim doc --project ./src/nosey.nim
```

