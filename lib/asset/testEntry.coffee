window.TEST = {
    handlers:[]
    register:(handler)->
        @handlers.push handler
}
setTimeout (()->
    $ ()->
        test = ()->
            if window.TEST.handlers.length < 0
                return
            handler = window.TEST.handlers.pop()
            handler ()->
                test()
        test()
    ),0