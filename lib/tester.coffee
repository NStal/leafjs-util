util = require("./util.coffee")
_ = require("lodash")
wrench = require("wrench")
cheerio = require("cheerio")
pathModule = require("path")
fs = require("fs")
express = require("express")
CoffeeScript = require("coffee-script")
Less = require("less")
commander = (require "commander")
program = commander.usage("[options] <target widgetSource.coffee>")
    .option("-p,--add-path <path>","add pathes other than CWD to search root")
    .option("-r,--server-root <path>","change test server root other than CWD")
    .option("-s,--test-style-sheet <path>","add an stylesheet to test page")
    .option("-e,--test-entry <path>","path to your own test logic")
    .option("-j,--jquery <path>","specify the jquery path")
    .option("-l,--leafjs <path>","specify the leafjs path")
    .option("-g,--test-page <path>","path to your own index.html of the test page")
    .option("-t,--temp-path <path>","path to temp file")
    .option("--use-bare","don't add anything to the index.html of this test")
    .option("--port <port>","port of the test server")
    .option("--host <host>","host of the test server")
    .parse(process.argv)
server = express()
defaultServerRoot = "./"
defaultServerHost = "0.0.0.0"
defaultServerPort = 8000
defaultTempPath = "/tmp/"
pathes = (program.addPath or "").split(",").map (item)->item.trim()
if "./" not in pathes and "." not in pathes
    pathes.unshift "./"

serverRoot = program.serverRoot or defaultServerRoot
serverPort = parseInt(program.port) or defaultServerPort
serverHost = program.host or defaultServerHost
tempPath = program.tempPath or defaultTempPath
tempPath = pathModule.join tempPath,"leaf-tester"
indexHtml = null
server.get "/",(req,res,next)->
    build()
    res.end(indexHtml)
server.get "*",(req,res,next)->
    filePath = pathModule.join tempPath,req.url
    console.log "try get",filePath
    if fs.existsSync filePath
        fs.createReadStream(filePath).pipe(res)
    else
        next()


server.use "/",express.static(serverRoot)
server.listen serverPort,serverHost


testTargetPath =  program.args[0]
if not testTargetPath
    commander.help()

testIndexTemplate = fs.readFileSync(pathModule.join(__dirname,"asset/index.html"),"utf8");

jqueryPath = program.jquery || pathModule.join(__dirname,"asset/jquery.js")
leafJsPath = program.leafjs || pathModule.join(__dirname,"asset/leaf.js")
testLogicPath = program.testEntry or pathModule.join(__dirname,"asset/testEntry.coffee")

dependencies = [
    jqueryPath
    leafJsPath
    testLogicPath
].map (item)->
    return {path:item}
htmlDependencies = null
build = ()->
    if fs.existsSync tempPath
        wrench.rmdirSyncRecursive tempPath
    if not fs.existsSync tempPath
        wrench.mkdirSyncRecursive tempPath
    testDeps = resolve {path:testTargetPath},[{path:testTargetPath,expand:true}]
    htmlDependencies = dependencies.concat testDeps
    console.log "solve dependencies",htmlDependencies
    indexHtml = prepareFiles(htmlDependencies)
resolve = (fileInfo,deps)->
    file = fileInfo.path
    if pathModule.extname(file) isnt ".coffee"
        return deps
    if not fileInfo.expand
        return deps
    content = util.getFileInSearchPath file,pathes
    lines = content.split("\n").filter (line)->line.trim()
    for line in lines
        asVar = false
        if line[0] is "#" and line[1] isnt "#"
            continue
        if line.indexOf("## require ") isnt 0
            break
        params = line.substring(2).trim().split(" ").filter (item)->item
        depPath = params[1]
        if params[2] is "as" and params[3]
            asVar = true
        if pathModule.basename(depPath) in (deps.map (info)-> pathModule.basename(info.path))
            continue
        if not depPath
            throw new Error "invalid require clause '#{line.trim()}', missing target file."
        deps.unshift {path:depPath,asVar:asVar}
        if pathModule.extname(depPath) is ".coffee"
            resolve depPath,deps
    return deps

prepareFiles = (files)->
    $ = cheerio.load testIndexTemplate
    for fileInfo in files
        file = fileInfo.path
        if fileInfo.asVar
            preparer["#"](file,$)
            continue
        ext = pathModule.extname(file)
        if preparer[ext]
            preparer[ext](file,$)
        else
            throw new Error "unkown ext type #{ext} of file #{file}"
    html = $.html()
    fs.writeFileSync pathModule.join(tempPath,"index.html"),html
    return html
preparer = {
    ".html":(path,$)->
        content = util.getFileInSearchPath path,pathes
        $("body").append(content)
        
    ".js":(path,$)->
        src = path
        target = pathModule.join tempPath,pathModule.basename path
        util.copySync src,target
        $("head").append("<script src='./#{pathModule.basename(path)}'></script>\n")
    ".coffee":(path,$)->
        content = CoffeeScript.compile util.getFileInSearchPath path,pathes
        target = pathModule.join tempPath,pathModule.basename(path,".coffee")+".js"
        fs.writeFileSync target,content
        $("head").append("<script src='./#{pathModule.basename(target)}'></script>\n")
    ".css":(path,$)->
        src = path
        target = pathModule.join tempPath,pathModule.basename path
        util.copySync src,target
        $("head").append("<link rel='stylesheet' href='./#{pathModule.basename(target)}' type='text/css' media='screen' />\n")

    ".less":(path,$)->
        content = null
        Less.render (util.getFileInSearchPath path,pathes),(err,result)->
            if err
                throw err
            content = result
        
        target = pathModule.join tempPath,pathModule.basename(path,".less")+".css"
        fs.writeFileSync target,content
        
        $("head").append("<link rel='stylesheet' href='./#{pathModule.basename(target)}' type='text/css' media='screen' />\n")
    "#":(path,$)->
        params = path.split("#").filter (item)->item
        path = params[0]
        varName = params[1]
        if varName is "var"
            varName = pathModule.basename path,pathModule.extname(path)
        content = util.getFileInSearchPath path,pathes
        jsContent = "window.#{varName} = #{JSON.stringify(content)}"
        fileName = "import-var-#{varName}.js"
        target = pathModule.join tempPath,fileName
        fs.writeFileSync target,jsContent
        $("head").append("<script src='./#{fileName}'></script>\n")

}


build()