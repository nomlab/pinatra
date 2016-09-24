require 'sinatra'
require './picasa_client'
require 'json'

def album_name_to_id(client, album_name)
  album = client.album.list.entries.find do |a|
    a.title == album_name
  end
  return album && album.id
end

picasa_client = Pinatra::PicasaClient.new.client

get "/hello" do
  "Suzuki Shinra!!"
end

get "/:album/photos" do
  contents = []
  album_id = album_name_to_id(picasa_client, params[:album])
  return "Not found" unless album_id
  album = picasa_client.album.show(album_id, {thumbsize: "128c"})
  album.photos.each do |p|
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
  "pinatra_photo_list(" + contents.to_json + ");"
end
