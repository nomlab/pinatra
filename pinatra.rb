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
  album = find_album_by_name(picasa_client, params[:album])
  return "Not found" unless album

  cache_file = pinatra_cache_file_name(album)
  return File.open(cache_file).read if File.exists?(cache_file)

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
  content = "pinatra_photo_list(" + contents.to_json + ");"

  File.open(cache_file, "w") do |file|
    file.print content
  end
  return content
end
