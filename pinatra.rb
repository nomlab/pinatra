require 'sinatra'
require './picasa_client'
require 'json'

def find_album_by_name(client, album_name)
  client.album.list.entries.find {|a| a.title == album_name}
end

def pinatra_cache_file_name(album)
  "pinatra.#{album.id}.#{album.etag}.cache"
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
    photos = picasa_client.album.show(album.id, {thumbsize: "128c"}).photos
    photos.each do |p|
      thumb = p.media.thumbnails.first
      photo = {
        src: p.content.src,
        title: p.title,
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
