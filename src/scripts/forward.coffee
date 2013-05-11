# Description:
#   Forwards HTTP requests received by this Hubot.
#
# Commands:
#   Hubot forward enable <url>  -  Turn forwarding on.  
#   Hubot forward disable       -  Turn forwarding off.
#   Hubot forward info          -  Show plugin status.
#
#
# Notes: 
#   This script relies on Hubot's brain to store it's configuration.
#
# Author:
#   jjmason
#
Url   = require 'url'
Util  = require 'utile' 

module.exports = (robot) -> 
  # the entire state of this script
  forwardUrl = null
  
  # make sure we can save our state
  return robot.logger.error("forward.coffee: I need a brain!") unless robot.brain?

  # load it from the brain
  robot.brain.on 'loaded', -> 
    forwardUrl = robot.brain.data.forward?.url
    
  # update and save state
  setForwardUrl = (url) ->
    forwardUrl = if url? then Url.parse(url) else null
    robot.brain.data.forward = {url:forwardUrl}
    robot.brain.save()
    
  # report info in chat
  showInfo = (msg) ->
    if forwardUrl then msg.send "Hubot is forwarding http requests to #{Util.format forwardUrl}."
    else msg.send "Hubot isn't fowarding http requests."
    
  # the main attraction
  forwardRequest = (req, res, next) ->
    robot.logger.debug "fowarding request #{req.method} #{req.url}"
    
    useHttps = /^http/.test forwardUrl.protocol
    opts = 
      method: req.method
      path: req.url
      headers: req.headers
      port: forwardUrl.port ? (if useHttps then 443 else 80)
      hostname: forwardUrl.hostname
      
    factory = require(if useHttps then 'https' else 'http').request
    
    fwd = factory opts, (res) ->
      robot.logger.debug "received response to forwarded request: #{res.statusCode}"
      robot.logger.error("http error while forwarding request") if res.statusCode >= 400
    
    onerror = (err) ->
      robot.logger.error "error forwarding request: #{err}"
      fwd.end()
    fwd.on 'error', onerror
    req.on 'error', onerror
    
    req.pipe(fwd)
    next()
    
  # commands
  robot.respond /forward enable (\S+)/i, (msg) ->
    setForwardUrl msg.match[1]
    showInfo msg
    
  robot.respond /forward disable/i, (msg) ->
    setForwardUrl null
    showInfo msg
    
  robot.respond /forward info/i, (msg) ->
    showInfo msg
    
    
  # install as connect middleware
  robot.router.use (req, res, next) ->
    return unless forwardUrl?
    forwardRequest req, res, next
  # HACK! we need to be the *first* middleware, I guess...
  robot.router.stack.unshift robot.router.stack.pop()
  
    
    
  
  