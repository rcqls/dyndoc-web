## ===============================
## Services in a human being world
## ===============================
##
## Structure: a group of dyndoc server managed by different people.
## All these people belong to the same collaborative community.
##
## Different kinds of users who always need to be invited first (except for public services)
## *) admin: manages a (group of) dyndoc server(s)
## *) developper: can create services
## *) user: can use services
## *) public: can use restricted services (or demo services)

## common services would be synchronized between servers
## need to be invited by the owner

# get the status of the pdf
# if status is open:
# => to some specific dyndoc user
# => to all the dyndoc members
# => to any internet person
# We need to choose the rooms where to execute the dyndoc document

# From now, I want to be able to write public page!
# maybe in html!!!

class DyndocWorld < Scorched::Controller
	include DyndocRenee
    	include DyndocLogin
	
 	render_defaults.merge!(
  		dir: File.join($dyndoc_web[:devel_path],"views"), #File.expand_path('../../../views', __FILE__)
    	engine: 'dyn_html'
    )

	 

	get /\/(.*\.(?:pdf|html))$/ do |filename|
	 
		puts "world:html"
		# select the shortest and more recently created path
		file=[]

		tmp=File.join(public_world_root(""),filename)
		p tmp
		file << tmp if File.exists? tmp
		file += (Dir[File.join(public_world_root(""),"*")]+Dir[File.join(public_world_root(""),"*","*")]).map{|w|
			p File.join(w,"**",filename)
			tmp=Dir[File.join(w,"**",filename)]
			p tmp
			tmp
		}
		file=file.flatten.sort_by{|e|
			res=e.split("/").length.to_f + ("0."+(Time.now - File.mtime(e)).to_i.to_s).to_f
			#p res
			res
		}
		#p file
		halt "No file" if file.empty?
		run Rack::File.new(file[0])
	end

	get "/*.dyn_html"  do |dyn|
		puts "world";p dyn
		if dyn =~/^SitePath\/(.*)/
			sitePath,filePath=$1.split("/Html/")
			path=nil
			path=world_filename(sitePath) if sitePath =~ /.*\.html$/
			unless path
				filePath=$1 if filePath =~ /(.*)\.dyn_html$/
				p [sitePath,filePath]
				filePath=$1 if filePath =~ /^#{sitePath}\/(.*)/
				p [sitePath,filePath]
				path=world_filename([sitePath,filePath])+".html"
			end
			p ([path,File.exists?(path)])
			if File.exists? path
				puts "redirect html";p "/"+public_relative_filename(path)
				redirect "/"+public_relative_filename(path)
			end
			["Home","Projects"].each do |prefix|
				path=public_filename([prefix,sitePath,filePath],:site)+".html"
				p ([path,File.exists?(path)])
				if user_authorized? and File.exists?(path) 
					puts "redirect local html";p "/"+public_relative_filename(path)
					redirect! "/"+public_relative_filename(path)
				end
			end
			
			halt "Unreachable or unauthorized page!"
		else
			  
			file=world_filename(dyn)
			if File.exists? file
				render file.to_sym, layout: "demo/layout/world_cqls.dyn".to_sym
			else
				halt "world/#{dyn} Not found"
			end

		end
	end

	post 'link' do
		 
			puts "world/link"
			filename=request.params["filename"]
			state=request.params["state"]
			p [filename,state]
			halt world_update_link(filename,state)
		
	end

	

end
