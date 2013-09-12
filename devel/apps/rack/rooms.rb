class DyndocRooms < Scorched::Controller
	include DyndocRenee
    include DyndocLogin
	
	render_defaults.merge!(
  		dir: File.join($dyndoc_web[:devel_path],"views"), #File.expand_path('../../../views', __FILE__),
  		engine: 'dyn_html'
    )

	get /\/static\/(.*\.dyn_html)/ do |dyn|
		puts "rooms/static"
		  
		p dyn
		file=user_filename(dyn)
		if File.exists? file
			redirected_page=user_local_filename(build_static_page({:src=>file}, layout: "layout/base.dyn"))
			puts redirected_page
			redirect "/rooms/"+redirected_page						
		end
	end


	get /\/(.*\.(?:pdf|csv|RData|html))/ do |filename|
			 
#to fix				unless logout?
## Google View does not work since no authentification is performed by them!
## I need to add a random key to authorize the viewer. 
#puts "FILES";p filename;p user_filename(filename); p user_authorized?
				if user_authorized?
					file=user_filename(filename)
=begin
				if File.exists? file
					unless (tmp=Dir[file+".*"]).empty?
						cpt= (tmp[0] =~ /#{file}\.(\d*)\.pdf/) ? ($1.to_i+1 % 1000) : 0
						tmp.each{|f| FileUtils.rm(f)}
					else
						cpt=0
					end
					FileUtils.ln_s file, file+".#{cpt}.pdf"
					file += ".#{cpt}.pdf"
				end
=end
					puts "file";p file
					run! Rack::File.new(file)
				end
		end

		get "/*.dyn_html" do |dyn|
			 
				file=user_filename(dyn)
				if File.exists? file
					render_safe file.to_sym, layout: "layout/base.dyn".to_sym
				end
		end

		post "/new_file" do
				puts "new file"
				dir,filename,ext=user_filename(request.params["dir"]),request.params["filename"],request.params["type"]
				p [dir,filename,ext]
				ok=true
				ok=false unless filename =~ /^[a-z,A-Z,0-9,\.]/
				if ext=="dir"
					dir=File.dirname(dir) unless File.directory? dir
					dir2=File.join(dir,filename)
					FileUtils.mkdir_p dir2
					ok=user_local_filename(dir2)
					halt ok ? ok : "{success: false}"
				elsif ext=="rename"
					new_filename,filename=filename,dir
					new_filename=File.join(File.dirname(filename),new_filename)
					p [ext,filename,new_filename]
					halt "false" unless File.dirname(new_filename)==File.dirname(filename)
					new_filename += File.extname(filename) if File.extname(new_filename).empty?
					halt "false" if File.exists? new_filename
					begin
						puts "rename";p filename;p new_filename
						FileUtils.mv filename,new_filename
						halt "true"
					rescue
						halt "false"
					end
				else
					ok=false if ok and  !(File.exists? dir)
					if ok
						dir=File.dirname(dir) unless File.directory? dir
						filename+="."+ext unless filename.split(".")[-1] == ext
						dir2,file2=File.split(File.join(dir,filename))
						file2=File.join(dir2,file2)
						ok=!(File.exists? file2)
						if ok
							FileUtils.mkdir_p dir2
							File.open(file2,"w") do |f| f << "" end
						end
					end
					ok=user_local_filename(file2) if ok
					##puts "ok";p ok
					halt ok ? ok  : "{success: false}"
				end
		end

		post "/clone" do
				puts "clone"
				filename=user_filename(request.params["filename"])
				p filename

				dir,base,ext=File.dirname(filename),File.basename(filename,".*"),File.extname(filename)
				extra,extra2,i="_COPY","",1
				while File.exists? (copy=File.join(dir,base+extra+extra2+ext))
					i+=1
					extra2=i.to_s
				end
				begin
					FileUtils.cp filename,copy
					halt "true"
				rescue
					halt ""
				end
		end


		post "/save" do
				filename,content=request.params["filename"],request.params["content"]
				if user_authorized?
					file=user_filename(filename)
					File.open(file,"w") do |f|
						f << content
					end
					halt "true"
				else
					halt "false"	
				end			
		end

		post "/move" do
				puts "move"
				filename=user_filename(request.params["filename"]);
				halt "false" if File.symlink? filename #do not move a dropbox or system directory 
				dir=user_filename(request.params["dir"]);
				p filename;p dir
				dir=File.dirname(dir) unless File.directory? dir
				begin
					if File.exists? filename and File.exists? dir
						p filename;p dir
						FileUtils.mv  filename,dir
						halt "true"
					else
						halt "false"
					end
				rescue
					halt "false"
				end
		end

		post "/copy" do
				puts "copy"
				filename=user_filename(request.params["filename"]);
				halt "false" if File.symlink? filename #do not copy a dropbox or system directory 
				dir=user_filename(request.params["dir"]);
				#p filename;p dir
				dir=File.dirname(dir) unless File.directory? dir
				begin
					if File.exists? filename and File.exists? dir
						#p Dir[dir+"/*"];p Dir[dir+"/*"].include? File.join(dir,File.basename(filename))
						if Dir[dir+"/*"].include? File.join(dir,File.basename(filename))
							base,ext=File.basename(filename,".*"),File.extname(filename)
							extra,extra2,i="_COPY","",1
							while File.exists? (copy=File.join(dir,base+extra+extra2+ext))
								i+=1
								extra2=i.to_s
							end
							p filename;p copy
							if File.directory? filename
								 FileUtils.cp_r  filename,copy
							else
								FileUtils.cp  filename,copy
							end
						else
							p filename;p dir
							if File.directory? filename
								 FileUtils.cp_r  filename,dir
							else
								FileUtils.cp  filename,dir
							end
						end
						halt "true"
					else
						halt "false"
					end
				rescue
					halt "false"
				end
		end


		post "/delete" do
				puts "delete"
				filename=user_filename(request.params["filename"])
				p filename
				ok=File.exists? filename
				if ok
					if File.directory? filename
						ok=Dir["#{filename}/*"].empty?
						puts "directory!!";p Dir["#{filename}/*"]
						FileUtils.rm_rf filename if ok
					else
						FileUtils.rm filename
					end
				end
				halt "#{ok}|||#{user_size}"
		end

		post "/upload" do
				puts "upload"
	  			filename, target = request.params['qqfile'],request.params["target"]
	  			target=user_filename(target)
	  			p [filename,target]
	  			target=File.dirname(target) unless File.directory? target
	  			newf = File.open(File.join(target,filename), "w")
	  			str =  request.body.read
	  			newf.write(str)
	  			newf.close
	  			p '{success: true, sizeMo: \''+user_size.to_s+'\' }'
	  			halt '{success: true, sizeMo: \''+user_size.to_s+'\' }'
		end

		post "/export" do

				puts "rooms/export"
				## make the zip file (see dyndoc for windows tip)
				## prepare the zip file! The user is in charge to save the zip file!
				## do not forget to create the link


		end

		post "/free" do
				puts "rooms/free"
				## remove zip file
				## check that the zip file is the last one!
				## remove the content directory not the directory!
				## what about world??????
			

		end

		get "/admin" do
			 
				puts "rooms/admin"


		end

		get "quota" do
					halt user_size.to_s
		end


	

end