class DyndocRsrc < Scorched::Controller

		include DyndocLogin
    	include DyndocRenee
    	include DyndocCSVFile
	 

		get /\/(.*\.(?:png|jpg|pdf|jpeg|css|js))$/ do |filename|
			 
				puts "rsrc:png|jpg|jpeg|css|js"
				# select the shortest and more recently created path
				file=[]
				tmp=File.join(public_rsrc_root(""),filename)
				puts "rsrc-file";p tmp
				file << tmp if File.exists? tmp
				file += (Dir[File.join(public_rsrc_root(""),"*")]+Dir[File.join(public_rsrc_root(""),"*","*")]).map{|w|
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
				halt "No rsrc file #{filename}" if file.empty?
				run Rack::File.new(file[0])
		end

		# give the complete filename for other extensions
		get /\/(.*\.(?:csv|RData|dyn|R|rb|gem|jar|java|tgz|zip|tar\.gz|exe|no\_ext))$/ do |filename|
			 
				#puts "rsrc get"
				#p filename
				#TODO: to complete if unexisting page but existing completed page for an authorized user
				filename=File.join(File.dirname(filename),File.basename(filename,".*")) if File.extname(filename)==".no_ext"
				#p filename
				file=File.join(public_rsrc_root(""),filename)
				#puts "rsrc file";p file
				run Rack::File.new(file)
		end

		## question: is it possible to add this kind of server-side content from the client-side? 
		controller "/datatable" do
			get "csv" do
					filename,csv_mode=request.params["csv"],request.params["csv_mode"]
					col_sep=request.params["col_sep"]
					echo=request.params["sEcho"].to_i
					#puts "request.params";p request.params
					col_sep=";" unless col_sep
					halt jsonp_protected(({"sEcho" => -1}).to_json,request.params["callback"]) unless filename
					halt jsonp_protected(({"sEcho" => -1}).to_json,request.params["callback"]) if csv_mode and csv_mode=="rooms" and !user_authorized?
					file= (csv_mode and csv_mode=="rooms") ? user_filename!(filename) : File.join(public_rsrc_root(""),filename)
					
					##puts "rsrc datatable file";p file
					if File.exists? file
						csv_table=csv_datatable(file,col_sep)
					else
						varnames=request.params["varnames"].split(",").map{|e| e.to_sym}
						csv_new(file,varnames,col_sep)
						csv_table=[]
					end
					csv_table=csv_table.sort_by{|e| e[request.params["iSortCol_0"].to_i+1].capitalize}
					csv_table=csv_table.reverse if request.params["sSortDir_0"]=="desc"
					# object model with DT_RowId (useful for editable)
					res=csv_table.empty? ? csv_table : csv_table[request.params["iDisplayStart"].to_i,request.params["iDisplayLength"].to_i].map{|row|
	  						e={"DT_RowId" => row[0]}
	  						e={"DT_RowClass" => request.params["RowClass"]} if request.params["RowClass"]
	  						row[1..-1].each_with_index {|r,i| e[i.to_s]=r}
	  						e
	  					}

					res={
						"sEcho" => echo,
	  					"iTotalRecords" => csv_table.length,
	  					"iTotalDisplayRecords" => csv_table.length,
	  					"aaData" => res
	  				}
	  				res=res.to_json
	  				##puts "datatable csv\n";puts res
	  				halt jsonp_protected(res,request.params["callback"])
			end

			post "csv_addrow" do
					
					filename,csv_mode=request.params["csv"],request.params["csv_mode"]
					col_sep=request.params["col_sep"]
					col_sep=";" unless col_sep
					#puts filename
					halt jsonp_protected("false",request.params["callback"]) unless filename
					halt jsonp_protected("false",request.params["callback"]) if csv_mode and csv_mode=="rooms" and !user_authorized?
					file= (csv_mode and csv_mode=="rooms") ? user_filename!(filename) : File.join(public_rsrc_root(""),filename)
					
					#p file
					#p request.params
					#p FasterCSV.read(file,:col_sep=> col_sep)[0]
					new_row=FasterCSV.read(file,:col_sep=>col_sep)[0].map{|e| request.params[e.to_s] ? request.params[e.to_s] : "false"}
					#puts"new_row";p new_row
					csv_addrow(file,new_row,col_sep)
					halt jsonp_protected("true",request.params["callback"])
			 
			end

			post "csv_updatecell" do

					## TODO: jsonp or callback
					#puts "rsrc/updatecell"
					filename,csv_mode=request.params["csv"],request.params["csv_mode"]
					col_sep=request.params["col_sep"]
					col_sep=";" unless col_sep
					#puts filename
					halt request.params["value"] unless filename
					halt request.params["value"]  if csv_mode and csv_mode=="rooms" and !user_authorized?
					file= (csv_mode and csv_mode=="rooms") ? user_filename!(filename) : File.join(public_rsrc_root(""),filename)
					
					#p file
					#p request.params

					csv_updatecell(file,request.params["id"],request.params["columnName"],request.params["value"],col_sep)
					
					halt request.params["value"]

			end

		end


		post "/save" do
			 
				filename,content=request.params["filename"],request.params["content"]
				file=public_filename(filename,:public)
				puts "rsrc/save: file #{file} saved"
				File.open(file,"w") do |f|
					f << content
				end
				halt "true"
				 
			
		end
	
end