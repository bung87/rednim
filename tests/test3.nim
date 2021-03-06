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
test "can scan":
  let souce =  getCurrentDir() / "src" / "rednim.nim"
  const name = when defined(windows) : "rednim.exe" else : "rednim"
  let exe = getCurrentDir() / "src" / name
  let (output,code) = execCmdEx("nim c " & souce)
  if code != 0:
    raise newException(IOError, output)
  const port = 6799
  process = startProcess(exe,args=["--port",$port],options={poParentStreams})
  var con:AsyncRedis
  var i = 0
  while i < 500:
    try:
      con = waitFor openAsync("localhost", port.Port,false,500)
      break
    except:
      i += 1
      continue

  check $waitFor(con.execCommand("MSET", @["key1", "Hello","key2","World"])) == "OK"
  check waitFor(con.execCommand("EXISTS",@["key1"])) == RedisValue(kind:vkInt,i: 1)
  check $waitFor(con.execCommand("SCAN")) == """@[0, key1, key2]"""
  check $waitFor(con.execCommand("MSET", @["key3", "Hello","key4","World","key5", "Hello","key6","World"])) == "OK"
  check $waitFor(con.execCommand("MSET", @["key7", "Hello","key8","World","key9", "Hello","key10","World"])) == "OK"
  check $waitFor(con.execCommand("MSET", @["key11", "Hello","key12","World"])) == "OK"
  check $waitFor(con.execCommand("SCAN","1")) == """@[11, key2, key3, key4, key5, key6, key7, key8, key9, key10, key11]"""
  check $waitFor(con.execCommand("SCAN","5")) == """@[0, key6, key7, key8, key9, key10, key11, key12]"""
  asyncCheck(con.shutdown())
  process.terminate
