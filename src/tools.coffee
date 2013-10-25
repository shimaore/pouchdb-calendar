$ = jQuery = require 'jquery-browserify'

@logger = (txt) ->
  console.log txt
  elem = $ '<span></span>'
  elem.text txt
  ($ '#logger').prepend elem
