import std/[os, hashes, tables, sets, sugar, json]

type 
  DirState* = object
    dirName*: string
    dirHash*: Hash
    fileHashes*: Table[string, Hash]
  NewChangedDeleted* = object
    new*: HashSet[string]
    changed*: HashSet[string]
    deleted*: HashSet[string]

proc newDirState*(dirName: string): DirState =
  ## Creates a new DirState,
  ## representing the state of a directory and files within.
  ## This includes subdirectories.
  result.dirName = dirName
  for relativePath in dirName.walkDirRec(relative=true, checkDir=true):
    result.fileHashes[relativePath] = (dirName/relativePath).readFile.hash
  result.dirHash = result.fileHashes.hash

proc getFileSet*(s: DirState): HashSet[string] =
  ## Creates a HashSet of the file names in s.fileHashes.
  result = collect(initHashSet()):
    for fn in s.fileHashes.keys: {fn}

proc updateDirState*(s: var DirState): NewChangedDeleted =
  ## Mutates the passed DirState to be in sync with its represented directory.
  ## Returns 3 HashSets of new, changed and deleted files.
  let newState = newDirState(s.dirName)
  if newState.dirHash != s.dirHash:
    result.new = newState.getFileSet - s.getFileSet
    result.deleted = s.getFileSet - newState.getFileSet
    let possiblyChanged = s.getFileSet.intersection newState.getFileSet
    for fn in possiblyChanged:
      if s.fileHashes[fn] != newState.fileHashes[fn]:
        result.changed.incl fn
    s = newState

proc defaultFileConverter*(sourceFilePath, targetDir: string) =
  ## The default fileConverter in applyDirState.
  ## It simply copies the file to targetDir.
  echo "copying " & sourceFilePath & " to " & targetDir
  copyFileToDir(sourceFilePath, targetDir)

proc defaultFileRemover*(sourceFilePath, targetDir: string) =
  ## The default fileRemover in applyDirState.
  ## It simply removes the file from targetDir.
  let file = targetDir/sourceFilePath.splitPath.tail
  echo "removing " & file
  removeFile(file)

proc applyDirState*(
  sourceState: DirState,
  targetDir: string,
  diffSets = NewChangedDeleted(),
  fileConverter: proc (sourceFilePath, targetDir: string)
    = defaultFileConverter,
  fileRemover: proc (sourceFilePath, targetDir: string)
    = defaultFileRemover,
) =
  ## Applies the desired state, based on the diffSets,
  ## fileRemover and fileConverter to the targetDir.
  ## `fileConverter` is called for every new or changed file in the sourceDir.
  ## `fileRemover` is called for every removed file in the sourceDir.
  ## WARNING: This doesn't watch the state of the targetDir,
  ## so if the targetDir is manipulated by something else,
  ## those changes might be overwritten.
  let changed = diffSets.new + diffSets.changed
  for fn in changed:
    fileConverter(sourceState.dirName/fn, targetDir/fn.splitPath.head)
  for fn in diffSets.deleted:
    fileRemover(sourceState.dirName/fn, targetDir/fn.splitPath.head)

proc watch*(
  sourceDir, targetDir: string,
  interval = 5000,
  fileConverter: proc (sourceFilePath, targetDir: string)
    = defaultFileConverter,
  fileRemover: proc (sourceFilePath, targetDir: string)
    = defaultFileRemover,
  sourceStateJson = "",
  doNothingWhenNoJson = true
) =
  ## Scans sourceDir every {interval} milliseconds, using updateDirState().
  ## Then applies desired state to targetDir, using applyDirState().
  ## Optionally a file name can be passed in sourceStateJson.
  ## It will supply the initial source DirState 
  ## and will be updated while watching.
  ## WARNING: When using CTRL-C to stop the watcher while it's writing a file,
  ## I'm not sure what happens.
  let withJson = sourceStateJson != ""
  var 
    ss: DirState
    ncd: NewChangedDeleted
  if withJson:
    try:
      ss = readFile(sourceStateJson).parseJson.to(ss.type) 
    except JsonParsingError, IOError:
      let e = getCurrentException()
      echo $e.name & ": " & e.msg
      echo "using current state of " & sourceDir & 
        " and creating " & sourceStateJson & " later"
      echo ""
      if doNothingWhenNoJson:
        ss = sourceDir.newDirState
      else:
        ss = DirState(dirName: sourceDir)
  else:
    if doNothingWhenNoJson:
      ss = sourceDir.newDirState
    else:
      ss = DirState(dirName: sourceDir)
  while true:
    sleep(interval)
    ncd = ss.updateDirState
    applyDirState(ss, targetDir, ncd, fileConverter, fileRemover)
    if withJson and ncd != NewChangedDeleted():
      writeFile(sourceStateJson.addFileExt("json"), $ %*ss)

proc runOnce*(
  sourceDir, targetDir: string,
  fileConverter: proc (sourceFilePath, targetDir: string)
    = defaultFileConverter,
  fileRemover: proc (sourceFilePath, targetDir: string)
    = defaultFileRemover,
  sourceStateJson = "",
) =
  let withJson = sourceStateJson != ""
  var 
    ss: DirState
    ncd: NewChangedDeleted
  if withJson:
    try:
      ss = readFile(sourceStateJson).parseJson.to(ss.type) 
    except JsonParsingError, IOError:
      let e = getCurrentException()
      echo $e.name & ": " & e.msg
      echo "using current state of " & sourceDir & 
        " and creating " & sourceStateJson & " later"
      echo ""
      ss = DirState(dirName: sourceDir)
  else:
    ss = DirState(dirName: sourceDir)
  ncd = ss.updateDirState
  applyDirState(ss, targetDir, ncd, fileConverter, fileRemover)
  if withJson:
    writeFile(sourceStateJson.addFileExt("json"), $ %*ss)

when isMainModule:
  const
    sourceDir = "src"
    targetDir = "tests"
    jsonFile = "hashes.json"
  runOnce(sourceDir, targetDir, sourceStateJson=jsonFile)
  # runOnce(sourceDir, targetDir)
