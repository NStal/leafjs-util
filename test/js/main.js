if(!console.debug){
    console.debug = console.log
}
console.debug("I'm main")
console.debug("Require `a`")
console.debug("Name of a:",require("a").name)
