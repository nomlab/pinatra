require 'sinatra'
require './picasa_client'
require 'json'
require 'digest/sha1'

# FIXME: refactor client.api interface
def find_album_by_id(client, album_id)
  client.api(:album, :show, album_id)
end

def extension_to_content_type(key)
  type = {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    jpe: "image/jpeg",
    JPG: "image/jpeg",
    JPEG: "image/jpeg",
    JPE: "image/jpeg",
    png: "image/png",
    PNG: "image/png"
  }
  return type[key]
end

################################################################
## Pinatra Photo cache
module Pinatra
  class PhotoCache
    def get(album)
      cache_file = album_cache_file_name(album)

      return File.open(cache_file).read if File.exists?(cache_file)
      return nil # not found
    end

    def save(album, json)
      cache_file = album_cache_file_name(album)

      File.open(cache_file, "w") do |file|
        file.print json
      end
      return self
    end

    private

    def album_cache_file_name(album)
      sha1 = Digest::SHA1.hexdigest("#{album.id}" + album.etag)
      "pinatra.#{sha1}.cache"
    end
  end # class PhotoCache
end

################################################################
# helpers

helpers do
  def cache
    @cache ||= Pinatra::PhotoCache.new
  end

  def picasa_client
    @picasa_client ||= Pinatra::PicasaClient.new.client
  end
end

get "/hello" do
  "Suzuki Shinra!!"
end

get "/:album_id/photos" do
  contents = []
  callback = params['callback']
  album = find_album_by_id(picasa_client, params[:album_id])
  return "Not found" unless album

  unless json = cache.get(album)
    photos = picasa_client.api(:album, :show, album.id, {thumbsize: "128c"}).photos
    photos.each do |p|
      thumb = p.media.thumbnails.first
      photo = {
        src: p.content.src,
        title: p.title,
        id: p.id,
        thumb: {
          url: thumb.url,
          width: 128,
          height: 128
        }
      }
      contents << photo
    end
    json = contents.to_json
  end

  if callback
    content_type :js
    content = "#{callback}(#{json});"
  else
    content_type :json
    content = json
  end

  cache.save(album, json)
  return content
end

# Upload contents of files as image.
# Accept POST method with multipart/form-data.
# Set parameter name to /file\d+/ (e.g. file1, file2 ...).
# Example: curl -F file1=@./image1.jpg -F file2=@./image2.jpg \
#          'localhost:4567/nomnichi/photo/new'
# Default photo name is uploaded file name.
# If specify, set parameter such as following.
# /nomnichi/photo/new?title=photoname
post "/:album_id/photo/new" do
  album = find_album_by_id(picasa_client, params[:album_id])
  return "Not found" unless album

  contents = []
  title = params['title']
  files_key = params.keys.select {|key| key =~ /file\d+/}
  files_key.each do |key|
    param = params[key]
    file_type = param[:filename].split(/./).last

    photo = picasa_client.api(:photo, :create, album.id, binary: param[:tempfile].read, content_type: (extension_to_content_type(file_type) || "image/jpeg"), title: (title || param[:filename]))
    thumb = photo.media.thumbnails.first
    hash = {
      src: photo.content.src,
      title: photo.title,
      id: photo.id,
      thumb: {
        url: thumb.url,
        width: 128,
        height: 128
      }
    }
    contents << hash
    title = nil unless title == nil
  end

  json = contents.to_json
  content_type :json

  return json
end
