pathModule = require("path")
crypto = require("crypto")
fs = require("fs")
wrench = require("wrench")

program = require("commander").usage("[option] <js-folder-root>")
    .option("-o,--output-file <path>","specify the output require configs")
    .option("-r,--root <root patah>","specifty the generated files root name")
    .option("--enable-debug","enable debug mode in config")
    .option("--set-version","set version for the config")
    .parse(process.argv)
outputFile = program.outputFile
outputFormat = "json"
indentCount = 4
jsIncludePath = program.args[0] or "./"
version = program.setVersion or null
enableDebug = program.enableDebug and true or false
if outputFormat is "json" and outputFile and fs.existsSync outputFile
    try
        config = JSON.parse fs.readFileSync outputFile,"utf8"
    catch e
        console.error "outputFile #{outputFile} exists, but is not a valid json."
        console.error "don't overwrite it."
        process.exit(1)
else
    config = {}
config.name = config.name or "leaf-require"
config.js = {}
config.debug = config.debug or enableDebug
if version
    config.version = version
files = wrench.readdirSyncRecursive jsIncludePath
fileWhiteList = [/\.js$/i]
files = files.filter (file)->
    for white in fileWhiteList
        if white.test file
            return true
    return false
files = files.map (file)->
    hash = crypto.createHash("md5").update(fs.readFileSync (pathModule.join jsIncludePath,file),"utf8").digest("hex").substring(0,6)
    return {
        path:file
        hash:hash
    }
config.js.root = program.root or ""
config.js.files = files

content = JSON.stringify config,null,indentCount
if outputFile
    fs.writeFileSync outputFile,content
else
    console.log content
process.exit(0)