# coding: utf-8
require 'sinatra'
require './googlephoto_client'
require 'json'
require 'digest/sha1'
# Add
require 'open-uri'
require 'yaml'

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

    def album_cache_file_name(album_id)
      sha1 = Digest::SHA1.hexdigest(album_id)
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

  def google_photo_client
    @google_photo_client ||= Pinatra::GooglePhotoClient.new.client
  end
end

get "/hello" do
  "Suzuki Shinra!!"
end

get "/photo/:photo_id" do
  CONFIG_PATH = "#{ENV['HOME']}/.config/pinatra/config.yml"
  config = YAML.load_file(CONFIG_PATH)

  params[:photo_id].gsub!(/\.jpg$/, "")
  photo_url = "photo/#{params[:photo_id]}.jpg"
  if !File.exist?(photo_url)
    photo = google_photo_client.get_photo(params[:photo_id]).to_h
    open("#{photo['baseUrl']}=w1024-h1024") do |file|
      open(photo_url, "w+b") do |output|
        output.write(file.read)
      end
    end
  end

  open(photo_url, "r") do |file|
    file.read
  end
end

get "/:album_id/photos" do
  CONFIG_PATH = "#{ENV['HOME']}/.config/pinatra/config.yml"
  config = YAML.load_file(CONFIG_PATH)

  contents = []
  callback = params['callback']
  album_id = params[:album_id]

  photos = google_photo_client.get_albumphotos(album_id).to_h["mediaItems"]

  # アルバムを取得後，各写真を保存する
  # public/photo以下に<photo_id>.jpgとして保存
  # photos.each do |p|
  #   unless File.exist?("public/photo/#{p["id"]}.jpg")
  #     open("#{p['baseUrl']}=w1024-h1024") do |file|
  #       filename = "#{p["id"]}.jpg"
  #       open("public/photo/#{filename}", "w+b") do |out|
  #         out.write(file.read)
  #       end
  #     end
  #   end
  # end

  photos.each do |p|
    photo = {
      src: "#{config["host_url"]}/photo/#{p["id"]}",
      title: p["filename"],
      id: p["id"],
      thumb: {
        url: p["baseUrl"],
        width: 128,
        height: 128
      }
    }
    contents << photo
  end
  json = contents.to_json

  if callback
    content_type :js
    content = "#{callback}(#{json});"
  else
    content_type :json
    content = json
  end



  # FIXME: アルバムに更新がなければ保存したキャッシュを使うほうがよい．
  #cache.save(album_id, json)
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
  album = find_album_by_id(google_photo_client, params[:album_id])
  return "Not found" unless album

  contents = []
  title = params['title']
  files_key = params.keys.select {|key| key =~ /file\d+/}
  files_key.each do |key|
    param = params[key]
    file_type = param[:filename].split(/./).last

    photo = google_photo_client.api(:photo, :create, album.id, binary: param[:tempfile].read, content_type: (extension_to_content_type(file_type) || "image/jpeg"), title: (title || param[:filename]))
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
