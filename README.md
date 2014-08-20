# leafjs-util

A handy util for easy testing UI components written in coffee inside browser environment. With a given coffee script, it will mockup an tempary html and import all you needs than make them available at http://localhost:8000/ by default. Currently only support and tested under linux and darwin.

# install
```bash
sudo npm install -g leafjs-util
# or if you already setup PATH to the local modules
# run it without sudo instead
```

# usage
```bash
leafjs-tester <path-to-your-script>
# and then visit http://localhost:8000/ to see the mockuped html
```
# help
```bash
leafjs-tester -h
```

# example
see example forlder for detail

# rules

Every line start with "## " is considered as an inline command, you can using inline commands to make testing faster and easyer

## import css/less

The css will be put to header

```coffee-script
## require ./style.css
## require ./style.less
```

## import js

The js will be put to header

```coffee-script
## require ./lib.js
```

## import coffee

The coffee will be understand by the leafjs-util's rule and expanded and then compiled into js.

```coffee-script
## require ./test.coffee
```

## import html into body

html will be import and insert into body as the order you requires it.

```coffee-script
## require ./header.html
## require ./body.html
## require ./footer.html
```

## import any file as a local variable

```coffee-script
## require ./format.html as formatTemplate
console.log("we import formatTemplate, the value is",formatTemplate)
```

# other static resource

Any file inside the working directory you call the command will be available as long as it's name not conflict with the imported file's base name. Say ./example.json will be available at http://localhost:8000/example.json.

