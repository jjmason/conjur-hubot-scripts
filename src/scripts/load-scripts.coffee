# Description:
#   Tell Hubot to (re)load scripts.
#
# Commands:
#   Hubot, load <module|path>
#   Hubot, show require cache
#
# Author:
#   jjmason
#
_ = require 'underscore'
_.str = require 'underscore.string'
Util = require 'util'

module.exports = (robot) ->
  robot.respond /load\s*(\S+)/, (msg) ->
    module = _.str.trim(msg.match[1])
  robot.respond /show require cache/i, (msg) ->
    emit = _.map _.keys(require.cache), (key) -> "require.cache: #{key}"
    msg.send emit...
    
    