{Adapter,Robot,TextMessage,EnterMessage,LeaveMessage} = require '/Users/whz/Projects/Node/a-hubot/node_modules/hubot'

FacebookApi  = require 'facebook-api'
FacebookChat = require 'facebook-chat'
{ExtendedAdapter} = require 'hubot-extended-core'

util    = require 'util'
utilTools = require './tools'

access_token = process.env.HUBOT_FACEBOOK_ACCESS_TOKEN
appId = process.env.HUBOT_FACEBOOK_APP_ID
facebookId = process.env.HUBOT_FACEBOOK_USER_ID

class Facebookbot extends ExtendedAdapter
  send: (envelope, messages...) ->
    for msg in messages
      console.log "Sending to #{envelope.room}: #{msg}"

      @client.send envelope.user.jid, msg

      #@user_conversation(@profile.id, msg)

  reply: (envelope, messages...) ->
    for msg in messages
      if msg.attrs? #Xmpp.Element
        @send envelope, msg
      else
        @send envelope, "#{envelope.user.name}: #{msg}"

  self = ''

  run: ->
    self = @
    options =
    @profile
    @roster =

    @robot.logger.info util.inspect(options)

    @client = new FacebookChat
      facebookId: facebookId,
      appId : appId,
      accessToken : access_token

    @client.on 'online', @.onOnline
    @client.on 'error', @.onError
    @client.on 'presence', @.onPresence
    @client.on 'roster', @.onRoster
    @client.on 'message', @.onMessage
    @client.on 'composing', @.onComposing
    @client.on 'vcard', @.onVcard

    @options = options

    @robot.brain.on 'loaded', () ->
      self.flags.data_loaded = true;

    console.log "+++"

  onOnline: () ->
    console.log "online"

    #Get friend list
    self.client.roster()

    #Get a vcard
    self.client.vcard()

    fbapi = FacebookApi.user(access_token)

    fbapi.me.info (err, data) ->
      if err
        console.log "Error: " + JSON.stringify(err)
      else
        console.log "Data: " + JSON.stringify(data)
        self.profile = data
        self.robot.name = data.first_name

    #Get a friend vcard
    #self.client.vcard('-FACEBOOK_ID@chat.facebook.com');

    self.emit "connected"

  onError: (error) =>
    console.log "error! #{error}"

    #if error.code == "ECONNREFUSED"
    #  console.log "Connection refused, exiting"
    #else if error.children?[0]?.name == "system-shutdown"
    #  console.log  "Server shutdown detected, exiting"
    #else
    #  console.log util.inspect(error.children?[0]?.name, { showHidden: true, depth: 1 })

  onPresence: (presence) =>
    console.log "presence: " + self.findFriendName(presence.from)

  onRoster: (roster) =>
    console.log "received roster"
    self.roster = roster

  onMessage: (message) =>
    userId = self.userIdFromJid(message.from)
    sender = self.userForId userId,
      room: 0,
      type:  message.type
      jid: message.from

    sender.name = self.findFriendName(message.from)

    # create a new conversation if it doesn't exist
    if self.flags.data_loaded is true
      fbapi = FacebookApi.user(access_token)

      fbapi.get(userId).info (err, data) ->
        if err
          console.log "Error: " + JSON.stringify(err)
        else
          self.extend_user_property(userId, data)

    console.log message.body
    # reformat leading @mention name to be like "name: message" which is
    # what hubot expects
    regex = new RegExp("^@#{self.robot.name}\\b", "i")
    hubot_msg = message.body.replace(regex, "#{self.robot.name}")

    self.receive new TextMessage(sender, hubot_msg)

  onComposing: (from) ->
    console.log "from " + self.findFriendName(from)

  onVcard: (vcard) ->
    console.log "received vcard"
    console.log vcard

  findFriendName: (from) ->
    sender = utilTools.findById(self.roster, from)
    sender.name || ''

  userIdFromJid: (jid) ->
    try
      return jid.match(/^-(\d+)@chat\./)[1]
      # return from.substr(1, from.indexOf('@'));
    catch e
      console.log "Bad user JID: #{jid}"
      return null


exports.use = (robot) ->
  new Facebookbot robot
