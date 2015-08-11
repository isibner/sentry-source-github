_ = require 'lodash'
path = require 'path'
url = require 'url'
uuid = require 'node-uuid'
querystring = require 'querystring'
request = require './request'
github = require './github'

class GithubSource extends require('events').EventEmitter
  @NAME: 'github'
  @DISPLAY_NAME: 'GitHub (public)'
  @ICON_FILE_PATH: path.join(__dirname, '../', 'github_icon.gif')
  @AUTH_ENDPOINT: '/auth'

  constructor: ({@config, @serverConfig, @packages}) ->
    {@BASE_URL, @DASHBOARD_URL} = @serverConfig
    {@CLIENT_ID, @CLIENT_SECRET, @BOT_USERNAME, @BOT_PASSWORD, @USER_AGENT} = @config

  initializeAuthEndpoints: (router) ->
    scope = 'public_repo, admin:repo_hook'
    handshake_endpoint_uri = url.resolve @BASE_URL, "/plugins/sources/#{@NAME}/auth_handshake"
    router.get @AUTH_ENDPOINT, (req, res) =>
      req.session._gh_oauth_state = uuid.v4()

      github_auth_redirect_uri = 'https://github.com/login/oauth/authorize?' + querystring.stringify {
        client_id: @CLIENT_ID,
        redirect_uri: handshake_endpoint_uri,
        scope: scope,
        state: req.session._gh_oauth_state,
        userAgent: @USER_AGENT
      }
      res.redirect github_auth_redirect_uri

    router.get '/auth_handshake', (req, res) =>
      if not req.query.code
        req.flash 'error', 'No code received from GitHub auth. Did you authorize the app?'
        return res.redirect @DASHBOARD_URL
      request {
        url: 'https://github.com/login/oauth/access_token',
        method: 'POST',
        userAgent: @USER_AGENT,
        data: {
          client_id: @CLIENT_ID,
          client_secret: @CLIENT_SECRET,
          code: req.query.code,
          redirect_uri: handshake_endpoint_uri,
          state: req.session._gh_oauth_state
        }
      }, (err, response) =>
        if err
          console.error err.stack
          req.flash 'error', "Error with github auth. #{err.message}"
          return res.redirect @DASHBOARD_URL
        {access_token} = querystring.parse(response.body)
        delete req.session._gh_oauth_state
        req.user.pluginData.github ?= {}
        req.user.pluginData.github.accessToken = access_token
        req.user.markModified('pluginData.github.accessToken')
        req.user.save =>
          console.log 'successfully saved user'
          req.flash 'success', 'Successfully authenticated with GitHub'
          res.redirect @DASHBOARD_URL

  isAuthenticated: (req) ->
    return req.user?.pluginData.github?.accessToken?

  getRepositoryListForUser: (user, callback) ->
    github.userAuth(user.pluginData.github.accessToken).getAllRepos(callback)

  activateRepo: (userModel, repoId, callback) ->
    [user, repo] = repoId.split('/')
    webhookUrl = url.resolve @BASE_URL, "/plugins/sources/#{@NAME}/webhook"
    github.userAuth(userModel.pluginData.github.accessToken).activateRepo {
      @BOT_USERNAME, @BOT_PASSWORD, user, repo, webhookUrl
    }, (err, hookData) ->
      return callback(err) if err
      userModel.pluginData.github.hooks ?= {}
      userModel.pluginData.github.hooks[repoId] = hookData.id
      userModel.markModified("pluginData.github.hooks.#{repoId}")
      userModel.save(callback)

  cloneUrl: (userModel, repoModel) ->
    "https://#{@BOT_USERNAME}:#{@BOT_PASSWORD}@github.com/#{repoModel.repoId}.git"

  initializeHooks: (router) ->
    router.post '/webhook', (req, res) =>
      if req.get('X-GitHub-Event') is 'ping'
        console.log 'Got ping!'
      else
        console.log 'Got push!'
        console.log req.body
        @emit 'hook', {repoId: req.body.repository.full_name}
      res.send {success: true}

  deactivateRepo: (userModel, repoId, callback) ->
    [user, repo] = repoId.split('/')
    webhookId = userModel.pluginData.github.hooks[repoId]
    github.userAuth(userModel.pluginData.github.accessToken).deactivateRepo {
      @BOT_USERNAME, @BOT_PASSWORD, user, repo, webhookId
    }, (err) ->
      return callback(err) if err
      delete userModel.pluginData.github.hooks[repoId]
      userModel.markModified("pluginData.github.hooks")
      userModel.save(callback)


module.exports = GithubSource
