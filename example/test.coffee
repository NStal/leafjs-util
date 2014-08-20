# Any comment start with '## require' is a command
# ## require can be used to import any other module
# 
# For example "## require ./style.css" will include this css into html
# supported require format are .css .less .coffee .js
# Additionally, a required .coffee will also obey this rule
# You can also import a file of any extension as a string variable
# such as "## require ./template.html as varName"
#
# 
## require ./style.css
## require ./body.html
## require ./lib.js
## require ./format.html as format


$ ()->
    console.log "you should be able to find body.partial.html to be inside body"
    $("body #button").click ()->
        # format is introduced by "## require ./format.html as format"
        # function getPrettyTime is introduced by "## require ./lib.js"
        $("body #container").html format.replace "{{time}}",window.getPrettyTime()