#@require ./clockWidget.less
#@import ./clockWidget.html as template
class Clock extends Leaf.Widget
    constructor:(template)->
        super(template)
        @start()
    start:()->
        @timer = setInterval (()=>
            @node$.text new Date().toString()
            ),100
    stop:()->
        clearTimeout @timer

TEST.register (done)=>
    clock = new Clock(template)
    document.body.appendChild clock.node
