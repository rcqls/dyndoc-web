class DyndocPlay < Scorched::Controller

	include DyndocRenee
    include DyndocLogin

  	render_defaults.merge!(
  		dir: File.join($dyndoc_web[:devel_path],"views"), #File.expand_path('../../../views', __FILE__)
    	engine: 'dyn_html'
    )
	

	 
	post "/latex" do
		 
		puts "latex"
		filename=user_filename(request.params["filename"])
		ok,msg=true,""
		if File.exists? filename
			dir,name=File.split(filename)
			curdir=FileUtils.pwd
			FileUtils.cd dir
			cmd="pdflatex -halt-on-error -file-line-error "+name 
			puts "cmd="+cmd
			out=`#{cmd}`.split("\n")
			if out[-2].include? "Fatal error"
				ok,msg=false,out[-4..-1].join("\n")
			end
			FileUtils.cd curdir
			
		else
			ok,msg=false,"Error: "+filename+" does not exist!"
		end
		halt ok ? "true" : "false|||Compilation error:\n "+out[-4..-1].join("\n")+"}"
		 
	end

	post "/dyntex" do
		 
		puts "dyntex"
		filename=user_filename(request.params["filename"])
		p filename
		if File.exists? filename
			dir,name=File.split(filename)
			curdir=FileUtils.pwd
			FileUtils.cd dir
			cmd="dyndoc-client "+(request.params["dyndoc_options"] ? request.params["dyndoc_options"] : "")+" all -cspdf "+(request.params["document_options"] ? request.params["documents_options"] : "")+name#+"@127.0.0.1:6666" 
			puts "cmd="+cmd
			system(cmd)
			FileUtils.cd curdir
			halt '{success: true}'
		else
			halt '{success: false}'
		end
		 
	end

	post "/dyncli" do #for dyn and not necessarily latex file!
		 
		puts "dyncli"
		filename=user_filename(request.params["filename"])
		if File.exists? filename
			dir,name=File.split(filename)
			curdir=FileUtils.pwd
			FileUtils.cd dir
			cmd="dyndoc-client all -cspdf "+name+"@127.0.0.1:6666" 
			puts "cmd="+cmd
			system(cmd)
			FileUtils.cd curdir
			halt '{success: true}'
		else
			halt '{success: false}'
		end
		
	end


	post "/dyndoc" do
	 
	 	tacon=dyndoc_xml_tacon(request.params['update_value'],:style=>request.params["style"],:id=>request.params['id'])

		#p tacon
  		## quit
  		halt (tacon.empty? ? "Empty result! Maybe because of an error in <pre><code> #{code}</code></pre>" : tacon)
   	 		
   	end

   	post "/R" do
		 
	 	tacon=dyndoc_xml_tacon(request.params['update_value'],:style=>request.params["style"],:syntax=>"R",:id=>request.params['id'])

		#p tacon
  		## quit
  		halt (tacon.empty? ? "Empty result! Maybe because of an error in <pre><code> #{code}</code></pre>" : tacon)
	 		
   	end
	

end