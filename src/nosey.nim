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

proc defaultChangedFileHandler*(sourceFilePath, targetDir: string) =
  ## The default changedFileHandler in applyDirState.
  ## It simply copies the file to targetDir.
  echo "copying " & sourceFilePath & " to " & targetDir
  copyFileToDir(sourceFilePath, targetDir)

proc defaultDeletedFileHandler*(sourceFilePath, targetDir: string) =
  ## The default deletedFileHandler in applyDirState.
  ## It simply deletes the file from targetDir.
  let file = targetDir/sourceFilePath.splitPath.tail
  echo "deleting " & file
  removeFile(file)

proc applyDirState*(
  sourceState: DirState,
  targetDir: string,
  diffSets = NewChangedDeleted(),
  newFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultChangedFileHandler,
  changedFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultChangedFileHandler,
  deletedFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultDeletedFileHandler,
) =
  ## Applies the desired state, based on the diffSets,
  ## deletedFileHandler and changedFileHandler to the targetDir.
  ## `newFileHandler` is called for every new file in the sourceDir.
  ## `changedFileHandler` is called for every changed file in the sourceDir.
  ## `deletedFileHandler` is called for every deleted file in the sourceDir.
  ## WARNING: This doesn't watch the state of the targetDir,
  ## so if the targetDir is manipulated by something else,
  ## those changes might be overwritten.
  for fn in diffSets.new:
    newFileHandler(sourceState.dirName/fn, targetDir/fn.splitPath.head)
  for fn in diffSets.changed:
    changedFileHandler(sourceState.dirName/fn, targetDir/fn.splitPath.head)
  for fn in diffSets.deleted:
    deletedFileHandler(sourceState.dirName/fn, targetDir/fn.splitPath.head)

proc watch*(
  sourceDir, targetDir: string,
  interval = 5000,
  newFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultChangedFileHandler,
  changedFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultChangedFileHandler,
  deletedFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultDeletedFileHandler,
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
    applyDirState(
      ss,
      targetDir,
      ncd,
      newFileHandler,
      changedFileHandler,
      deletedFileHandler
    )
    if withJson and ncd != NewChangedDeleted():
      writeFile(sourceStateJson.addFileExt("json"), $ %*ss)

proc runOnce*(
  sourceDir, targetDir: string,
  newFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultChangedFileHandler,
  changedFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultChangedFileHandler,
  deletedFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultDeletedFileHandler,
  sourceStateJson = "",
) =
  ## Scans sourceDir once, using updateDirState().
  ## Then applies desired state to targetDir, using applyDirState().
  ## Optionally a file name can be passed in sourceStateJson.
  ## It will supply the initial source DirState 
  ## and will be updated with the new DirState.
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
  applyDirState(
    ss,
    targetDir,
    ncd,
    newFileHandler,
    changedFileHandler,
    deletedFileHandler
  )
  if withJson:
    writeFile(sourceStateJson.addFileExt("json"), $ %*ss)

proc watch*(
  sourceDir, targetDir: string,
  interval = 5000,
  newFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultChangedFileHandler,
  changedFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultChangedFileHandler,
  deletedFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultDeletedFileHandler,
  initialState = DirState(),
  doNothingWhenNoInitial = true
) =
  ## Scans sourceDir every {interval} milliseconds, using updateDirState().
  ## Then applies desired state to targetDir, using applyDirState().
  ## Optionally a DirState can be passed in initialState.
  ## It will supply the initial source DirState 
  ## WARNING: When using CTRL-C to stop the watcher while it's writing a file,
  ## I'm not sure what happens.
  let withInitial = initialState != DirState()
  var 
    ss: DirState
    ncd: NewChangedDeleted
  if withInitial:
    ss = initialState
  else:
    if doNothingWhenNoInitial:
      ss = sourceDir.newDirState
    else:
      ss = DirState(dirName: sourceDir)
  while true:
    sleep(interval)
    ncd = ss.updateDirState
    applyDirState(
      ss,
      targetDir,
      ncd,
      newFileHandler,
      changedFileHandler,
      deletedFileHandler
    )

proc runOnce*(
  sourceDir, targetDir: string,
  newFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultChangedFileHandler,
  changedFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultChangedFileHandler,
  deletedFileHandler: proc (sourceFilePath, targetDir: string)
    = defaultDeletedFileHandler,
  initialState = DirState(),
) =
  ## Scans sourceDir once, using updateDirState().
  ## Then applies desired state to targetDir, using applyDirState().
  ## Optionally a file name can be passed in sourceStateJson.
  ## It will supply the initial source DirState 
  ## and will be updated with the new DirState.
  let withInitial = initialState != DirState()
  var 
    ss: DirState
    ncd: NewChangedDeleted
  if withInitial:
    ss = initialState
  else:
    ss = DirState(dirName: sourceDir)
  ncd = ss.updateDirState
  applyDirState(
    ss,
    targetDir,
    ncd,
    newFileHandler,
    changedFileHandler,
    deletedFileHandler
  )

when isMainModule:
  const
    sourceDir = "src"
    targetDir = "tests"
    jsonFile = "hashes.json"
  runOnce(sourceDir, targetDir, sourceStateJson=jsonFile)
  # runOnce(sourceDir, targetDir)
