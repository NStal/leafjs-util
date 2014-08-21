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
    .option("-b,--build-package","build the file into a single js package rather than run it in browser")
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

if program.buildPackage
    dependencies = [
    ]
else
    dependencies = [
        jqueryPath
        leafJsPath
        testLogicPath
    ]
dependencies = dependencies.map (item)->
    return {path:item}
htmlDependencies = null
build = ()->
    if fs.existsSync tempPath
        wrench.rmdirSyncRecursive tempPath
    if not fs.existsSync tempPath
        wrench.mkdirSyncRecursive tempPath
    testDeps = resolve {path:testTargetPath,expand:true},[{path:testTargetPath,expand:true}]
    htmlDependencies = dependencies.concat testDeps
    if not program.buildPackage
        console.log "solve dependencies",htmlDependencies
    content = prepareFiles(htmlDependencies)
    if program.buildPackage
        console.log content
        process.exit(0)
    else
        indexHtml = content
        
    
resolve = (fileInfo,deps)->
    file = fileInfo.path
    if pathModule.extname(file) isnt ".coffee"
        return deps
    if not fileInfo.expand
        return deps
    content = util.getFileInSearchPath file,pathes
    results = []
    lines = content.split("\n").filter (line)->line.trim()
    lines = lines.filter (line)->line.indexOf("## require ") is 0
    lines.reverse()
    for line in lines
        console.log "solve line",line
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
        deps.unshift {path:depPath,asVar:asVar,varName:params[3]}
        if pathModule.extname(depPath) is ".coffee"
            resolve depPath,deps
    return deps

prepareFiles = (files)->
    if program.buildPackage
        processor = packager
    else
        processor = preparer
        $ = cheerio.load testIndexTemplate
    content = ""
    for fileInfo in files
        file = fileInfo.path
        if fileInfo.asVar
            if program.buildPackage
                content = processor["#"](fileInfo,content)
            else
                processor["#"](fileInfo,$)
            continue
        ext = pathModule.extname(file)
        if processor[ext]
            if program.buildPackage
                content = processor[ext](fileInfo,content)
            else
                processor[ext](fileInfo,$)
        else
            throw new Error "unkown ext type #{ext} of file #{file}"
    if content
        return content
    html = $.html()
    fs.writeFileSync pathModule.join(tempPath,"index.html"),html
    return html
preparer = {
    ".html":(fileInfo,$)->
        path = fileInfo.path
        content = util.getFileInSearchPath path,pathes
        $("body").append(content)
        
    ".js":(fileInfo,$)->
        path = fileInfo.path
        src = path
        target = pathModule.join tempPath,pathModule.basename path
        util.copySync src,target
        $("head").append("<script src='./#{pathModule.basename(path)}'></script>\n")
    ".coffee":(fileInfo,$)->
        path = fileInfo.path
        content = CoffeeScript.compile util.getFileInSearchPath path,pathes
        target = pathModule.join tempPath,pathModule.basename(path,".coffee")+".js"
        fs.writeFileSync target,content
        $("head").append("<script src='./#{pathModule.basename(target)}'></script>\n")
    ".css":(fileInfo,$)->
        path = fileInfo.path
        src = path
        target = pathModule.join tempPath,pathModule.basename path
        util.copySync src,target
        $("head").append("<link rel='stylesheet' href='./#{pathModule.basename(target)}' type='text/css' media='screen' />\n")

    ".less":(fileInfo,$)->
        path = fileInfo.path
        content = null
        Less.render (util.getFileInSearchPath path,pathes),(err,result)->
            if err
                throw err
            content = result
        
        target = pathModule.join tempPath,pathModule.basename(path,".less")+".css"
        fs.writeFileSync target,content
        
        $("head").append("<link rel='stylesheet' href='./#{pathModule.basename(target)}' type='text/css' media='screen' />\n")
    "#":(fileInfo,$)->
        path = fileInfo.path
        varName = fileInfo.varName
        if varName is "var"
            varName = pathModule.basename path,pathModule.extname(path)
        content = util.getFileInSearchPath path,pathes
        jsContent = "window.#{varName} = #{JSON.stringify(content)}"
        fileName = "import-var-#{varName}.js"
        target = pathModule.join tempPath,fileName
        fs.writeFileSync target,jsContent
        $("head").append("<script src='./#{fileName}'></script>\n");

}
packager = {
    ".html":(fileInfo,content)->
        path = fileInfo.path
        console.warn "//packge mode don't support include html #{fileInfo.path}"
        return content
    ".js":(fileInfo,content)->
        path = fileInfo.path
        js = util.getFileInSearchPath path,pathes
        return content + ";;;\n#{js}"
    ".coffee":(fileInfo,content)->
        path = fileInfo.path
        js = CoffeeScript.compile util.getFileInSearchPath path,pathes
        return content + ";;;\n#{js}"
    ".css":(fileInfo,content)->
        path = fileInfo.path
        css = util.getFileInSearchPath path,pathes
        return content + "(function(){var style = document.createElement('style');style.setAttribute('data-debug-path',#{JSON.stringify('path')});style.innerHTML = #{JSON.stringify(css)};document.head.appendChild(style)})()"
    ".less":(fileInfo,content)->
        path = fileInfo.path
        css = null
        Less.render (util.getFileInSearchPath path,pathes),(err,result)->
            if err
                throw err
            css = result
        return content + "(function(){var style = document.createElement('style');style.setAttribute('data-debug-path',#{JSON.stringify('path')});style.innerHTML = #{JSON.stringify(css)};document.head.appendChild(style)})()"
    "#":(fileInfo,content)->
        path = fileInfo.path
        varName = fileInfo.varName
        if varName is "var"
            varName = pathModule.basename path,pathModule.extname(path)
        content = util.getFileInSearchPath path,pathes
        jsContent = "window.#{varName} = #{JSON.stringify(content)}"
        return content + jsContent

}
build()
