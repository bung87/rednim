import asyncnet, asyncdispatch, net
import tables
import redisparser, strutils
const OK = "+OK\r\n"
const PONG = "+PONG\r\n"
const RequestError = "-Error $#\r\n"
var 
  clients {.threadvar.}: seq[AsyncSocket]
  kvStore = initTable[string, RedisValue]()


proc killClient(client: AsyncSocket) =
  var cIndex = clients.find(client)
  if -1 != cIndex:
    clients.del(cIndex)


proc receiveManaged*(this:AsyncSocket, size=1): Future[string] {.async.} =
  result = newString(size)
  discard await this.recvInto(addr result[0], size)
  return result

proc readStream(this:AsyncSocket, breakAfter:string): Future[string] {.async.} =
  var data = ""
  while true:
    if data.endsWith(breakAfter):
      break
    let strRead = await this.receiveManaged()
    data &= strRead
  return data

proc readMany(this:Socket|AsyncSocket, count:int=1): Future[string] {.async.} =
  if count == 0:
    return ""
  let data = await this.receiveManaged(count)
  return data

proc readForm(this:AsyncSocket): Future[string] {.async.} =
  var form = ""
  while true:
    let b = await this.receiveManaged()
    form &= b
    if b == "+":
      form &= await this.readStream(CRLF)
      return form
    elif b == "-":
      form &= await this.readStream(CRLF)
      return form
    elif b == ":":
      form &= await this.readStream(CRLF)
      return form
    elif b == "$":
      let bulklenstr = await this.readStream(CRLF)
      let bulklenI = parseInt(bulklenstr.strip()) 
      form &= bulklenstr
      if bulklenI == -1:
        form &= CRLF
      # elif bulklenI == 0:
      #   echo "IN HERE.."
      #   form &= await this.readMany(1)
      #   echo fmt"FORM NOW >{form}<"
      #   form &= await this.readStream(CRLF)
        # echo fmt"FORM NOW >{form}<"
      else:
        form &= await this.readMany(bulklenI)
        form &= await this.readStream(CRLF)

      return form
    elif b == "*":
        let lenstr = await this.readStream(CRLF)
        form &= lenstr
        let lenstrAsI = parseInt(lenstr.strip())
        for i in countup(1, lenstrAsI):
          form &= await this.readForm()
        return form
  return form

proc sendClientResponse(client: AsyncSocket, data: string) {.async.} =
  debugEcho "receive :" & data
  var response: string
  var value:RedisValue = decodeString(data)
  debugEcho "Operating on : " & $value
  # let PONG:RedisValue = RedisValue(kind:vkBulkStr,bs:"PONG")
  case value.kind:
  # A client sends the Redis server a RESP Array consisting of just Bulk Strings.
  of vkArray:
    case $value.l[0]:
    of "GET":
      if kvStore.hasKey($value.l[1]):
        response = $encodeValue kvStore[$value.l[1]]
      else:
        response = OK
    of "SET":
        kvStore[$value.l[1]] = value.l[2]
        response = OK
    of "MGET":
      for i in 1..<value.l.len:
        try:
          response = response & " " & $kvStore[$value.l[i]]
        except:
          response = response & " KO"
        response = response.strip()
    of "MSET":
      for i in countup(1, value.l.len-2, 2):
        kvStore[$value.l[i]] = value.l[i+1]
      response = OK
    of "DELETE":
      kvStore.del($value.l[1])
      response = OK
    of "FLUSH":
      kvStore.clear()
      response = OK
    of "QUIT":
      response = OK
      await client.send(response)
      client.close()
      killClient(client)
    of "PING":
      response = PONG
    of "SHUTDOWN":
      quit()
  else:
    response = RequestError % "Request must be list or simple string."
  await client.send(response)

proc handleClientRequest(client: AsyncSocket,cdata:string) {.async.} =
  await sendClientResponse(client,cdata)

proc processClient(client: AsyncSocket) {.async.} =
  while true:
    let cdata = await client.readForm
    if cdata.len == 0:
        killClient(client)
    else:
      await handleClientRequest(client,cdata)

proc serveAsync*(port=6379) {.async.} = 
  clients = @[]
  var server = newAsyncSocket(buffered = true)

  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr( Port(port) )
  server.listen()

  while true:
    let client = await server.accept()
    clients.add client
    asyncCheck processClient(client)


when isMainModule:
  proc rednim(port=6379): int =
    echo "server on port:" & $port
    result = 0
    asyncCheck serveAsync(port)
    runForever()
  import cligen; dispatch(rednim)
  