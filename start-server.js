const http = require('http');
const fs = require('fs').promises;
const { Elm } = require("./elm.js");
const app = Elm.Main.init();

function makeAsyncFun(sndFun, subFun) {
  const map = new Map();
  let id = 0;
  subFun.subscribe(function([result, id]) {
    const callback = map.get(id);
    map.delete(id);
    callback(result);
  });
  return function(arg) {
    return new Promise(function(resolve) {
      map.set(id, function(result) {
        resolve(result);
      });
      sndFun.send([arg, id]);
      id++;
    });
  }
}

app.ports.readFile.subscribe(async function([path, id]) {
  try {
    const string = await fs.readFile(path, 'utf-8');
    app.ports.readResult.send([string, id]);
  } catch(err) {
    app.ports.readResult.send([null, id])
  }
});

const getResponse = makeAsyncFun(app.ports.request, app.ports.response);
const server = http.createServer(async function(req, res) {
  const {
    statusCode,
    statusMessage,
    headers,
    body
  } = await getResponse(req);
  res.writeHeader(statusCode, statusMessage, headers);
  res.end(body);
});
server.listen(8080);
