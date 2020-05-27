# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest,asyncdispatch,redisclient
import redisparser
import os, osproc
var process: Process
test "set get quit":
  let souce =  getCurrentDir() / "src" / "rednim.nim"
  const name = when defined(windows) : "rednim.exe" else : "rednim"
  let exe = getCurrentDir() / "src" / name
  let (output,code) = execCmdEx("nim c " & souce)
  if code != 0:
    raise newException(IOError, output)
  const port = 6390
  process = startProcess(exe,args=["--port",$port],options={poParentStreams})
  var con:AsyncRedis
  var i = 0
  while i < 500:
    try:
      con = waitFor openAsync("localhost", port.Port,false)
      break
    except:
      i += 1
      continue

  # echo $con.execCommand("PING", @[])
  check $waitFor(con.execCommand("SET", @["auser", "avalue"])) == "OK"
  check $waitFor(con.execCommand("GET", @["auser"])) == "avalue"
  check $waitFor(con.quit()) == "OK"
  process.terminate
  
  # echo $con.execCommand("SCAN", @["0"])
