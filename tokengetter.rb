require 'thor'
require './picasa_client'

class TokenGetter < Thor
  desc "token", "Get picasa web api token"

  def token
    Pinatra::GooglePhotoClient.new(self)
  end
end

TokenGetter.start(ARGV)
