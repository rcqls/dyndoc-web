# Run with: rackup -s thin -p 3001 configDynam.ru
# then browse to http://localhost:3001
DYNDOCWEBMODE=:local #autodetection?
$dyndoc_web={:mode => DYNDOCWEBMODE}
$dyndoc_web[:local] = $dyndoc_web[:mode] == :local

require 'renee'
dynlib_path=nil
# The two first paths are for devel mode (the second one is maybe obsolete)
# The two last paths are for production mode (the last one is closed to be abandonned)
[["Dropbox","Dyndoc","System","dyndoc.ruby"],["DyndocVB","SharedFolder","System","dyndoc-ruby"],["DyndocVB","System","dyndoc.ruby"],[".gPrj","work","dyndoc.ruby"]].each {|prefix|
	dynlib_path=Dir[File.join(ENV["HOME"],prefix,"lib")][0] unless dynlib_path
}
$:.unshift(dynlib_path) if  dynlib_path

require 'dyndoc/common/tilt'
require "uv"
require "xmlsimple"
require "cgi"
require 'thread'

#Clever: Only Rack::Session has to exists before requiring redis-store to make Rack::Session::Redis available
begin 
	require 'redis-rack'
rescue LoadError
	require 'redis-store' 
end
redishost= ENV["REDIS_HOST"] || 'localhost'
redisport= ENV["REDIS_PORT"] || 6379
$redis = Redis.new(:host => redishost, :port => redisport) #needed here since used in some following libraries!

$dyndoc_web[:devel_path] = $dyndoc_web[:local] ? "/devel" : "/dynam"
$dyndoc_web[:vendor_path] = $dyndoc_web[:local] ? "vendor" : "common"

$dyndoc_web[:root] = $dyndoc_web[:local] ? "/Users/remy/tmp/dyndocWeb" : "/export/cqlsWeb"
$dyndoc_web[:public_path] = $dyndoc_web[:local] ? "/public" : "/public"
$dyndoc_web[:public_rooms] = $dyndoc_web[:local] ? "/public/rooms" : "/public/rooms"
$dyndoc_web[:public_site] = $dyndoc_web[:local] ? "/public/site" : "/public/site"
$dyndoc_web[:public_rsrc] = $dyndoc_web[:local] ? "/public/rsrc" : "/public/rsrc"
$dyndoc_web[:public_world] = $dyndoc_web[:local] ? "/public/world" : "/public/world"

["dyndoc_modules","jqueryfiletree"].each do |libname| require File.expand_path('..'+$dyndoc_web[:devel_path]+'/apps/lib/'+libname,__FILE__) end
(DyndocRackApps=["auth","play","demo","editor","rooms","site","world","sign","rsrc"]).each do |rack_app| require File.expand_path('..'+$dyndoc_web[:devel_path]+'/apps/rack/'+rack_app,__FILE__) end

## idée: ranger toutes les ressources (css, img, js, ...) par "tool": ace, dHtmlX, jqueryTools, jqueryEasyUI (jquery-easyui)

use Rack::Static, :urls => ['/images','/stylesheets','/tools','/javascripts'], :root => "#{$dyndoc_web[:vendor_path]}"

use Rack::Static, :urls => ['/dHtmlX','/ace'], :root => "#{$dyndoc_web[:vendor_path]}/tools"

use Rack::Static, :urls => ['/Downloads'], :root => 'public/rsrc'


unless $dyndoc_web[:local]
	use Rack::Session::Redis
else
	use Rack::Session::Cookie, :secret => ENV['RACK_COOKIE_SECRET']
end

Tilt::DynDocTemplate.init <<-DynDocLibs
Tools/Web/TabBar
Tools/Web/JQueryTools
Tools/Web/DHtmlX
Tools/Web/Code
Tools/Web/Ace
Tools/Web/Html
Tools/Web/Html/Styles
Tools/Web/Html/JQuery
Tools/Web/Layout
Tools/Tex/Tools
DynDocLibs

run Renee {

	#puts "for every path!"

	current_user_init unless $dyndoc_web[:local]

=begin
	File.open("/export/cqlsWeb/toto.log","a") do |f|
	f << env['PATH_INFO'] << "\n"
    f << env['SCRIPT_NAME'] << "\n"
    f << env['HTTP_HOST'] << "\n"
    f << env['SERVER_NAME'] << "\n"
    f << env['SERVER_PORT'] << "\n"
    end
=end

	init_referer

	init_http_host

	puts "rack-session!!!";p request.env["rack.session"]

	path '/' do
		get {
			case env['SERVER_NAME'].strip 
			when "sagag6.upmf-grenoble.fr"
				redirect! "/dev"
			when "cqls.upmf-grenoble.fr"
				redirect! "/CqlsCours/index.html"
			else
				redirect! ($dyndoc_web[:local] ? "/dev" : "/index.html")
			end
		}
	end

	path '/dev' do
		get {redirect! "/run/devel.dyn"}
	end

	path '/dev2' do
		get {redirect! "http://dyndoc.upmf-grenoble.fr:3002/run/devel.dyn"}
	end

	DyndocRackApps.each do |rack_app|
		path rack_app do
			run! eval("Dyndoc"+rack_app.capitalize)
		end		
	end

	path 'admin' do
		redirect! "/sign/admin"
	end

	path 'login' do
		get {redirect! 'auth'}
	end

	path 'run' do
		get { inline_safe! "path is /run/index", :dyn }

		var(/.*\.dyn/) {|tmpl|
			get { render_safe! tmpl, :dyn, :layout => "demo/layout/R_cqls.dyn" }
		}

		var(/.*\.dyn\_tex/) {|tmpl|
			get { render_safe! tmpl, :dyn_ttm, :layout => "demo/layout/R_cqls.dyn" }
		}

	end

	var(/.*\.html/) {|page|
			redirect! "/world/"+page
	}

	var(/.*\.(png|jpg|jpeg|css)/) {|page|
			redirect! "/rsrc/"+page
	}

}.setup {
  		views_path File.expand_path("..#{$dyndoc_web[:devel_path]}/views", __FILE__)
  		include DyndocLogin
  		include DyndocRenee
  		default_layout "demo/layout/R_cqls.dyn"
}
