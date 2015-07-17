_ = require 'lodash'
GithubAPI = require 'github'

class Github
  constructor: (authCreds, userAgent) ->
    @ghAPI = new GithubAPI {
      version: '3.0.0'
      protocol: 'https'
      host: 'api.github.com'
      timeout: 5000
      headers: {
        'user-agent': userAgent
      }
    }
    @ghAPI.authenticate(authCreds)

  getAllRepos: (callback) ->
    @ghAPI.repos.getAll {
      type: 'owner'
      sort: 'updated'
      direction: 'desc'
    }, (err, rawRepos) ->
      return callback(err) if err
      repos = _.map rawRepos, (rawRepo) ->
        return {name: rawRepo.name, id: rawRepo.full_name}
      callback(null, repos)

  activateRepo: ({BOT_USERNAME, user, repo, webhookUrl}, callback) ->
    collaboratorData = {user, repo, collabuser: BOT_USERNAME}
    hookData = {
      user
      repo
      name: 'web'
      events: ['push']
      active: true
      config: {
        url: webhookUrl
        content_type: 'json'
        insecure_ssl: 1
      }
    }
    @ghAPI.repos.addCollaborator collaboratorData, (err) =>
      return callback(err) if err
      @ghAPI.repos.createHook hookData, callback

  deactivateRepo: ({BOT_USERNAME, user, repo, webhookId}, callback) ->
    collaboratorData = {user, repo, collabuser: BOT_USERNAME}
    hookData = {user, repo, id: webhookId}
    @ghAPI.repos.deleteHook hookData, (err) =>
      callback(err) if err
      @ghAPI.repos.removeCollaborator collaboratorData, callback

module.exports =
  userAuth: (accessToken, userAgent) ->
    authCreds = {type: 'oauth', token: accessToken}
    return new Github(authCreds, userAgent)

  botAuth: (username, password, userAgent) ->
    authCreds = {type: 'basic', username, password}
    return new Github(authCreds, userAgent)
