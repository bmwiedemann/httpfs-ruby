# httpfs
# - author: jerome etienne jerome.etienne@gmail.com
# - license: MIT license
# - description: it allows to read files with http uri, additionnaly it supports the size
# - example of usage:
#   # mount the mount point via httpfs.rb
#   ruby httpfs.rb my/mount/point/directory
#   # read http file at from http://www.example.com/index.html with
#   cat my/mount/point/directory/www.example.com/index.html
# - this has been written very fast so use it at your own risk
#   but it passed the 'work-on-my-box' validation test :)

require 'fusefs'
include FuseFS

# needed to get the size of the file via http
require 'net/http'

require 'open-uri'


################################################################################
################################################################################
# fusefs binding for HttpFS
################################################################################
################################################################################
class HttpFS < FuseFS::FuseDir
  ##############################################################################
  # return true if path is a directory
  # TODO i have noidea what this code is doing - it is from OpenUriFS
  ##############################################################################
  def directory?(path)
    #puts "enter directory?{#{path})"
    uri = scan_path(path)
    fn = uri.pop
    return true if fn =~ /\.(com|org|net|us|de|jp|ru|uk|biz|info)$/
    return true if fn =~ /^\d+\.\d+\.\d+\.\d+$/
    ! (fn =~ /\./) # Does the last item doesn't contain a '.' ?
  end

  ##############################################################################
  # return true if path is a directory
  # TODO i have noidea what this code is doing - it is from OpenUriFS
  ##############################################################################
  def file?(path)
    #puts "enter file?{#{path})"
    uri = scan_path(path)
    uri.pop =~ /\./ # Does the last item contain a '.' ?
  end

  ##############################################################################
  # return the size of path
  # - determine the size using via a HEAD content-length
  ##############################################################################
  def size(path)
    #puts "enter size?{#{path})"
    #puts "size of uri http:/#{path}"
    # get the length of the http file by using the usual HEAD content_length
    uri = URI.parse("http:/#{path}")
    req = Net::HTTP::Head.new(uri.path)
    res = Net::HTTP.start(uri.host, uri.port) {|http| http.request(req) }
    #puts "length=#{res.content_length}"
    return res.content_length
  end
  
  
  ##############################################################################
  # raw_open 
  # - fails IIF mode != 'r'
  # - there is no real opening operation, it is just a placeholder for fusefs
  #   to agree on doing read :)
  ##############################################################################
  def raw_open(path,mode) 
    #puts "enter raw_open?{#{path}, #{mode})"
    # allow only open for read
    return false unless mode == 'r'
    # then it is considered open
    return true
  end
  

  ##############################################################################
  # raw_read to read only what is needed
  # - as opposed to read_file which read all the file
  ##############################################################################
  def raw_read(path, off, sz)
    #puts "enter raw_read?{#{path}, #{off}, #{sz})"
    uri = URI.parse("http:/#{path}")
    req = Net::HTTP::Get.new(uri.path)
    req.range=(off..off+sz-1)
    res = Net::HTTP.start(uri.host, uri.port) {|http| http.request(req) }
    case res
    when Net::HTTPPartialContent  
      res.body
    else      
      nil
    end
  end
  
end

################################################################################
################################################################################
# Main programm
################################################################################
################################################################################

exit unless (File.basename($0) == File.basename(__FILE__))

if (ARGV.size != 1)
  puts "Usage: #{$0} <directory>"
  exit
end

# get the dirname from the command line
dirname = ARGV.shift

if not File.directory?(dirname)
  puts "Usage: #{dirname} is not a directory."
  exit
end

# Start the FuseFS on HttpFS
root = HttpFS.new
FuseFS.set_root(root)
FuseFS.mount_under(dirname)
FuseFS.run # This doesn't return until we're unmounted.
