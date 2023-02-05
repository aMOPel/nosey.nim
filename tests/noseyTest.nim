import std/[unittest, os, tables, sets]
import nosey

suite "testing DirState":
  const 
    tempTestDir = "tempTestDir"
    sourceDir = tempTestDir/"source"
    sdSub = sourceDir/"sub"
    targetDir = tempTestDir/"target"
    tdSub = targetDir/"sub"
  createDir(sdSub)
  createDir(tdSub)
  var 
    sds = newDirState(sourceDir)
    tds = newDirState(targetDir)
    ncd: NewChangedDeleted

  test "newDirState":
    check sds.dirName == sourceDir
    check sds.fileHashes.len == 0
    check tds.dirName == targetDir
    check tds.fileHashes.len == 0

  test "no changes":
    let 
      sdsBefore = sds
      tdsBefore = tds
    check sds.updateDirState == NewChangedDeleted()
    check sds == sdsBefore
    check tds.updateDirState == NewChangedDeleted()
    check tds == tdsBefore

  test "new file":
    writeFile(sourceDir/"new.md", "hi")
    ncd = sds.updateDirState
    check ncd == NewChangedDeleted(new: toHashSet(["new.md"]))
    applyDirState(sds, targetDir, ncd)
    check tds.updateDirState == NewChangedDeleted(new: toHashSet(["new.md"]))
    writeFile(sdSub/"new.md", "hi")
    ncd = sds.updateDirState
    check ncd == NewChangedDeleted(new: toHashSet(["sub/new.md"]))
    applyDirState(sds, targetDir, ncd)
    check tds.updateDirState == NewChangedDeleted(new: toHashSet(["sub/new.md"]))

  test "changed file":
    writeFile(sourceDir/"new.md", "bye")
    ncd = sds.updateDirState
    check ncd == NewChangedDeleted(changed: toHashSet(["new.md"]))
    applyDirState(sds, targetDir, ncd)
    check tds.updateDirState == NewChangedDeleted(changed: toHashSet(["new.md"]))
    writeFile(sdSub/"new.md", "bye")
    ncd = sds.updateDirState
    check ncd == NewChangedDeleted(changed: toHashSet(["sub/new.md"]))
    applyDirState(sds, targetDir, ncd)
    check tds.updateDirState == NewChangedDeleted(changed: toHashSet(["sub/new.md"]))

  test "deleted file":
    removeFile(sourceDir/"new.md")
    ncd = sds.updateDirState
    check ncd == NewChangedDeleted(deleted: toHashSet(["new.md"]))
    applyDirState(sds, targetDir, ncd)
    check tds.updateDirState == NewChangedDeleted(deleted: toHashSet(["new.md"]))
    removeFile(sdSub/"new.md")
    ncd = sds.updateDirState
    check ncd == NewChangedDeleted(deleted: toHashSet(["sub/new.md"]))
    applyDirState(sds, targetDir, ncd)
    check tds.updateDirState == NewChangedDeleted(deleted: toHashSet(["sub/new.md"]))


  removeDir(tempTestDir)
