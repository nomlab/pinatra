require 'thor'
require './googlephoto_client'

class TokenGetter < Thor
  desc "token", "Get GooglePhoto web api token"

  def token
    Pinatra::GooglePhotoClient.new(self)
  end
end

TokenGetter.start(ARGV)
