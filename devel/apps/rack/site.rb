class DyndocSite < Scorched::Controller

	include DyndocRenee
	include DyndocLogin
	
	render_defaults.merge!(
		dir: File.join($dyndoc_web[:devel_path],"views"), #File.expand_path("#{$dyndoc_web[:root]}#{$dyndoc_web[:devel_path]}/views", __FILE__)
    	engine:  'dyn_html'
    )

	 
		get /\/(.*\.(?:pdf|csv|RData|html))$/ do |filename|

				#TODO: to complete if unexisting page but existing completed page for an authorized user
				file=site_filename(filename)
				puts "site file";p file
				run Rack::File.new(file)
		end


		get /(\/.*\.dyn_html)$/  do |dyn|
		 
			#puts "iiiii";p dyn
			if user_authorized?
				dir,dyn=File.split dyn
				p dir
				dir=$1 if world_mode=(dir =~ /^world\/(.*)/)
				#p world_mode
				layout,dyn=dyn.split("__") #this is only possible by adding combobox on layout
				dyn,layout=layout,false unless dyn
				layout="base" unless layout
				dyn=File.join(dir,dyn) unless dir=="."
				p dyn; p layout
				file=user_filename(File.join(dyn))
				p file
				if File.exists? file
					FileUtils.mkdir_p public_site_root unless File.directory? public_site_root
					redirected_page=build_static_page({:src=>file,:dest=>public_site_root}, engine: 'dyn_html', layout: ( false ? nil : "layout/#{layout}.dyn".to_sym),locals: {path: user_root, init_doc: true},world_mode: world_mode)
					puts public_relative_filename(redirected_page)
					redirect "/"+public_relative_filename(redirected_page)						
				end
			end
		
		end

	
end