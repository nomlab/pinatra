require 'sinatra'
require './picasa_client'
require 'json'
require 'pp'

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

# Upload contents of files as image.
# Accept POST method with multipart/form-data.
# Set patameter name to /file\d+/ (e.g. file1, file2 ...).
# Example: curl -F file1=@./image1.jpg -F file2=@./image2.jpg \
#          'localhost:4567/nomnichi/photo/new'
# Default photo name is uploaded file name.
# If specify, set parameter such as following.
# /nomnichi/photo/new?title=photoname
# FIXME?: if several files are uploaded and title parameter is set,
#        all uploaded photos titles are same.
post "/:album/photo/new" do
  album = find_album_by_name(picasa_client, params[:album])
  return "Not found" unless album

  contents = []
  files_key = params.keys.select {|key| key =~ /file\d+/}
  files_key.each do |key|
    param = params[key]
    # FIXME: decision by filename extension.
    photo = picasa_client.photo.create(album.id, binary: param[:tempfile].read, content_type: "image/jpeg", title: (params['title'] || param[:filename]))
    contents << photo.id
  end

  # FIXME: return more useful info
  return contents.join("\n")
end

# test method for Suzuki Shinra.
# following code will be deleted soon, perhaps.
post "/post/test" do
  # Please POST mutipart/form-data such as following.
  # curl -F test1=@./any.txt -F test2=@./any.org 'localhost:4567/post/test'
  # see also http://stackoverflow.com/questions/8659808/how-does-http-file-upload-work
  puts request.body.read
  puts ""

  puts "##########################################"
  puts "                 test1"
  puts "##########################################"
  pp params['test1']
  puts "##########################################\n\n"

  puts "##########################################"
  puts "                 test2"
  puts "##########################################"
  pp params['test2']
  puts "##########################################\n\n"

  puts "##########################################"
  puts "           contents of test1"
  puts "##########################################"
  puts params['test1'][:tempfile].read
  puts "##########################################"

  "OK"
end
