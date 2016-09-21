require 'thor'
require './picasa_client'

class TokenGetter < Thor
  desc "token", "Get picasa web api token"

  def token
    Pinatra::PicasaClient.new(self)
  end
end

TokenGetter.start(ARGV)
