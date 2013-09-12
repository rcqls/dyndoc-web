class DyndocEditor < Scorched::Controller
	 
  		include DyndocRenee
    	include DyndocLogin
	
	 	render_defaults.merge!(
	 		engine: 'dyn_html',
	 		dir: File.join($dyndoc_web[:devel_path],"views") #File.expand_path('../../../views', __FILE__)
    	)

		get "/init" do
			
				puts "get current file "
				p user_current_file
				p user_size
				p user_current_theme
				halt "#{login_user}|||#{user_current_file}|||#{user_current_pdf}|||#{user_size.to_s}|||#{user_current_theme}"

		end

		post "/curfile" do
			 
				puts "params[current_file]="+request.params["current_file"]
				user_current_file request.params["current_file"]
				halt '{success: true}'
		end

		post "/curpdf" do
				puts "params[current_pdf]="+request.params["current_pdf"]
				user_current_pdf request.params["current_pdf"]
				halt '{success: true}'
		end

		post "/curtheme" do
				puts "params[current_theme]="+request.params["current_theme"]
				user_current_theme request.params["current_theme"]
				halt '{success: true}'
		end

		get "/dir" do
				p request.params["id"]
				openids=request.params["openids"]
				puts "openids";p (openids ? openids.split(",") : "nil")
				user_current_openids openids if openids
				
				res=user_dir
				#puts "dir";puts res
				halt res
		end

		get "/world_dir" do
				p request.params["world id"]
				res=user_world_dir
				#puts "world dir";puts res
				halt res
		end

		post "/save" do
				puts "save"
	   	 		filename=user_filename(request.params['filename'])
	   	 		File.open(filename,"w") do |f|
	   	 			f << request.params['content']
	   	 		end
	      		halt user_size.to_s	
	   	end

	   	post "/load" do
				puts "load"
	   	 		filename=user_filename(request.params['filename'])
	   	 		p filename
	   	 		res=((File.exists? filename) && !(File.directory? filename)) ? File.read(filename) : ""
	   	 		p res
	      		halt res	
	   	end
	

end