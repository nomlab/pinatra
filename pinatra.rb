require 'sinatra'
require './picasa_client'
require 'json'

# FIXME: refactor client.api interface
def find_album_by_name(client, album_name)
  client.api(:album, :list, nil).entries.find {|a| a.title == album_name}
end

def pinatra_cache_file_name(album)
  "pinatra.#{album.id}.#{album.etag}.cache"
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

picasa_client = Pinatra::PicasaClient.new.client

get "/hello" do
  "Suzuki Shinra!!"
end

get "/:album/photos" do
  contents = []
  callback = params['callback']
  album = find_album_by_name(picasa_client, params[:album])
  return "Not found" unless album

  cache_file = pinatra_cache_file_name(album)
  if File.exists?(cache_file)
    json = File.open(cache_file).read
  else
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

  File.open(cache_file, "w") do |file|
    file.print json
  end

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
post "/:album/photo/new" do
  album = find_album_by_name(picasa_client, params[:album])
  return "Not found" unless album

  contents = []
  title = params['title']
  files_key = params.keys.select {|key| key =~ /file\d+/}
  files_key.each do |key|
    param = params[key]
    file_type = param[:filename].split(/./).last

    photo = picasa_client(:photo, :create, album.id, binary: param[:tempfile].read, content_type: (extension_to_content_type(file_type) || "image/jpeg"), title: (title || param[:filename]))
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
