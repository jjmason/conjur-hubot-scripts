# Description:
#   Forwards HTTP requests to another hubot.
#
# Commands:
#   Hubot, forward to <url>  -  Set the forwarding destination.
#   Hubot, turn forwarding <on|off> - Enable or disable forwarding.
#   Hubot, show forwarding info - Show what we're up to.
#   Hubot, <show|ignore> forwarding errors - Show or ignore http proxy errors.
#
# Notes:
#  Forwards all HTTP requests recieved by this hubot's router to another host.
#  Use case: You want to receieve service requests from github et.al. in your
#  dev environment, but don't want to reconfigure all of your services.
#
#
# Author:
#   jjmason
#
_ = require 'underscore'
http = require 'http'
https = require 'https'

Url = require 'url'
Util = require 'util'

protocols = {https:https, http:http}

class ForwardRequests
  constructor: (@robot) ->
    @on = false
    @to = { host:'localhost', port:8080, https:false }
    @showErrors = false

    @rooms = []
    @robot.brain.on('loaded', => @onBrainLoaded())
    @addCommands()
    @addMiddleware()

    @lastMsg = { }

  addCommands: ->
    @robot.respond /forward\s*(?:http)?\s*(?:requests)?\s*(?:to)?\s*(\S+)/i, (msg) =>
      @forwardTo msg.match[1], (strings...) -> msg.reply(strings...)

    @robot.respond /(?:turn)?\s*(?:request)?\s*forward(?:ing)?\s*(on|off)/i, (msg) =>
      @setOn msg.match[1], (strings...) -> msg.reply(strings...)

    @robot.respond /(show|ignore)\s*(?:request)?\s*(forward(?:ing)?)\s*errors/i, (msg) =>
      @setShowErrors msg.match[1] == 'show', (strings...) -> msg.reply(strings...)

    @robot.respond /(?:show)?\s*(?:request)?\s*forward(?:ing)?\s*(?:info)?/i, (msg) =>
      @showInfo (strings...)->
        msg.reply(strings...)

  showInfo: (reply) ->
    emit = ["request forwarding is #{if @on then 'on' else 'off'}"]
    if @to == null
      emit.push "no destination is set, so nothing's going to happen!"
    else
      emit.push "when forwarding is on requests go to #{@formatTo(@to)}"
    if @showErrors
      emit.push "proxy http errors are shown in chat"
    else
      emit.push "proxy http errors are silently discarded"
    reply(emit...)

  addMiddleware:->
    @robot.router.use (req,res,next) =>
      @forwardRequest(req,res,next)
    # hack: we have to get our handler in first or we miss requests!
    @robot.router.stack.unshift(@robot.router.stack.pop())

  forwardRequest: (req, res, next) ->
    # quick exit if we're disabled
    return next() unless @on and @to?

    # set up a proxy request
    protocol = if @to.https then https else http
    options =
      method:req.method
      path:req.url
      headers:_.extend(req.headers, {host:@to.host})
      hostname:@to.host
      port:@to.port
      
    proxy = protocol.request(options)
    # we have to handle this event or errors get thrown all the way up
    proxy.on 'error', (err) ->
      @reportProxyError(err)
      proxy.end()
    req.on 'data', (chunk) -> proxy.write(chunk)
    req.on 'error', (err) -> proxy.end()
    req.on 'end', -> proxy.end()
    # start's everything off
    next()


  reportProxyError:(err)->
    # TODO

  onBrainLoaded: ->
    data = @robot.brain.data.forwardRequests ? {}
    @robot.logger.info "data=#{Util.format data}"
    @on = !!data.on if _.has data, 'on'
    @to = data.to if _.has data, 'to'
    @showErrors = data.showErrors if _.has data, 'showErrors'

  save: (update) ->
    _.extend(@, update)
    data = (@robot.brain.data.forwardRequests ||= {})
    data.to = @to
    data.on = @on
    data.showErrors = @showErrors
    @robot.brain.data.forwardRequests = data
    @robot.brain.save()
    
  formatTo:(to)->
    "#{if to.https then 'https' else 'http'}://#{to.host}:#{to.port}"

  parseTo:(urlish)->
    return null if _.isNull(urlish)
    if _.isString(urlish)
      # help url.parse out a little here...
      urlish = "http://#{urlish}" unless /^http/i.test urlish
      url = Url.parse(urlish)
      to = url
    else
      to = urlish
    to = { }
    to.host = to.hostname ? to.host ? 'localhost'
    if to.protocol? and not to.https?
      to.https = /^https/.test to.protocol
    else if not to.https?
      to.https = false
    to.port = url.port or (if to.https then 443 else 80)
    to

  forwardTo: (rawUrl, reply) ->
    to = @parseTo(rawUrl)
    @save to:to
    reply "forwarding to #{@formatTo(to)}"

  setOn:(word, reply)->
    value = word == 'on'
    if @on == value
      message = "leaving forwarding #{word}"
    else
      message = "turned forwarding #{word}"
      @save('on':value)
    reply message

  setShowErrors: (value, reply) ->
    verbing = if value then 'showing' else 'ignoring'
    if value != @showErrors
      @save('showErrors':value)
      reply("#{verbing} request forwarding errors")
    else
      reply("already #{verbing} request forwarding errors")

module.exports = (robot) -> 
  new ForwardRequests(robot)
  

