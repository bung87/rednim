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
test "can add":
  let souce =  getCurrentDir() / "src" / "rednim.nim"
  let exe = getCurrentDir() / "src" / "rednim.out"
  let (output,code) = execCmdEx("nim c --hints:off --verbosity=0 " & souce)
  if code != 0:
    raise newException(IOError, output)
  process = startProcess(exe)
  var con:AsyncRedis
  var i = 0
  while i < 1000:
    try:
      con = waitFor openAsync("localhost", 6379.Port,false,500)
      break
    except:
      i += 1
      continue

  # echo $con.execCommand("PING", @[])
  check $waitFor(con.execCommand("SET", @["auser", "avalue"])) == "OK"
  check $waitFor(con.execCommand("GET", @["auser"])) == "avalue"
  check $waitFor(con.quit()) == "OK"
  process.close
  
  # echo $con.execCommand("SCAN", @["0"])
