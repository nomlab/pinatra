require 'sinatra'
require './picasa_client'

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
    contents << "---------------------------"
    contents << "Title: #{p.title}"
    contents << "<img src=\"#{p.media.thumbnails.last.url}.\">"
    contents << "---------------------------"
  end
  contents.join("<br>")
end
