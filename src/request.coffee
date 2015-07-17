https = require('https')
url = require('url')
querystring = require('querystring')

simpleRequest = (options, callback) ->
  {hostname, pathname} = url.parse(options.url)
  data = options.data

  request = https.request {
    hostname: hostname,
    path: pathname,
    method: options.method || 'GET',
    headers: {
      'user-agent': options.userAgent
    }
  }, ((response) ->
    response.setEncoding 'utf8'
    response.body = ''
    response.on 'data', (data) -> response.body += data
    response.on 'end', -> callback(null, response)
  )

  request.on 'error', callback

  if data and typeof data isnt 'string'
    data = querystring.stringify(data)

  request.write(data)
  request.end()

module.exports = simpleRequest
