$demo_dyndoc_codes_for_site={}

class DyndocDemo < Scorched::Controller

	include DyndocRenee
	include DyndocLogin
	
	render_defaults.merge!(
		dir:File.join($dyndoc_web[:devel_path],"views"), #File.expand_path('../../../views', __FILE__)
  		engine: 'dyn_html'
  	)	
	 
	get "/dyndoc" do
	    	 
	 	init_codes "demo/dyndoc_code.dyn"
  		render_safe "demo/dyndoc".to_sym, engine: 'dyn', layout: "demo/layout/dyndoc_cqls.dyn".to_sym

   	end

   	get "/R" do
    	 
	 	init_codes "demo/R_code.dyn", "R"
  		render_safe "demo/R".to_sym, engine: 'dyn', layout: "demo/layout/R_cqls.dyn".to_sym
   	 	   	
   	end
	   	
   	get "/dyndoc_choices" do
   	 
	 	tacon=dyndoc_xml_tacon($demo_dyndoc_codes_for_site["dyndoc"][request.params['update_value']],:style=> request.params['style'],:id=>request.params['id'])

		#puts "tacon:"+tacon
  		## quit
  		halt (tacon.empty? ? "Empty result! Maybe because of an error in <pre><code> #{req}</code></pre>" : tacon)
   	 	
   	end

   	post "/R_choices" do
   	 
	 	tacon=dyndoc_xml_tacon($demo_dyndoc_codes_for_site["R"][request.params['update_value']],:style=> request.params['style'],:syntax=>"R",:id=>request.params['id'])

		#puts tacon
  		## quit
  		halt (tacon.empty? ? "Empty result! Maybe because of an error in <pre><code> #{req}</code></pre>" : tacon)
   	 	
   	end
	

	def init_codes(codes_file,mode="dyndoc")
		#p mode;p $demo_dyndoc_codes_for_site[mode]
		mode2=mode 
		mode2="dyn" if mode2=="dyndoc"
		unless $demo_dyndoc_codes_for_site[mode]
	 		render codes_file, :dyn
	 		#p CqlsDoc::Utils.dyndoc_raw_text
	 		$demo_dyndoc_codes_for_site[mode]={}
	 		keys,codes=CqlsDoc::Utils.dyndoc_raw_text
	 		(0...(keys.length)).select{|i| res=keys[i]=~/\A\_\_([^|]*)\-#{mode2}\|/;keys[i]=$1 if res;res}.each do |i|
	 			$demo_dyndoc_codes_for_site[mode][keys[i]]=codes[i][0]
	 		end
	 		p $demo_dyndoc_codes_for_site[mode]
	 	end
	end

end