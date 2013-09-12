module DyndocRenee

	def dyndoc_xml_tacon(code,opts={})
		options={:id=>"editme",:format=>"xhtml",:syntax=>"dyndoc",:style=>"amy"}
		opts.delete(:style) unless opts[:style]
		options.merge!(opts)
		#p options
		if options[:style]
			unless dyndoc_globvar("layout.css4uv")
				dyndoc_globvar("layout.css4uv",options[:style])
			else
				dyndoc_globvar("layout.css4uv",(dyndoc_globvar("layout.css4uv").split(",")+[options[:style]]).uniq.sort.join(","))
			end
			#p dyndoc_globvar("layout.css4uv")
		end
		case options[:syntax]
 		when "R"
 			if code =~ /\A\s*\#+ fig(?:ure)/m
 				syntax,codeToRun="rfig", "{#rpng]"+code.split("\n")[1..-1].join("\n")+"[#img]public:rfig[#newR]TRUE[#}"
 			else
 				syntax,codeToRun="r", "{#rverb]"+code+"[#mode]raw[#rverb}"
 			end
 		else 
 			codeToRun,syntax=code,options[:syntax].downcase
 		end
 		## compute the result
 		res=inline(codeToRun, :dyn)
        syntax=File.join(Uv.syntax_path,syntax+".syntax") unless syntax=="rfig"
 		## create the HTML output!
 		if syntax=="rfig"
 			codeHTML=res
 		else
			codeHTML=Uv.parse(options[:syntax]=="R" ? res[1...-1] : code, options[:format], syntax, true, options[:style])
		end
 		#puts codeHTML
 		#p codeToRun
 		resHTML="<pre><code>"+res+"</code></pre>"
 		#puts "res";p resHTML
 		## save the page before!
 		tacon={"replaceContent"=>[
 			{"content"=>CGI::escapeHTML(code),"select"=>"##{options[:id]}-rawcode"},
 			{"content"=>codeHTML,"select"=>"##{options[:id]}-uvcode"},
 			{"content"=>CGI::escapeHTML(resHTML),"select"=>"##{options[:id]}-result"}
 		]}
 		#p tacon
 		XmlSimple.xml_out(tacon,'KeyAttr' => 'name' ,'RootName'=>"taconite", 'NoEscape' => true)
	end

	## to access and set global dyndoc variable
	def dyndoc_globvar(key,value=nil)
		if value
            if [:remove,:rm,:del,:delete].include?  value
                $curDyn.tmpl.filterGlobal.envir.remove(key)
            else
			     $curDyn.tmpl.filterGlobal.envir[key]= value
            end
		else
			$curDyn.tmpl.filterGlobal.envir[key]
		end
	end

	## to require some dyndoc libraries in ruby
	def DyndocRenee.dyndoc_require(libs)
		$curDyn.tmpl_doc.require_dyndoc_libs(libs)
	end

	## to place in a renee page path and in a corresponding layout!
	## Pb: this has to be placed inside the 
	## TODO: As taconite does, we can maybe declare different parts in the view dyndoc file
	## and use them in the layout!
	def dyndoc_yield(key,dyn_file)
		$curDyn.tmpl.filterGlobal.envir["yield_#{key}"]=render(dyn_file)
	end

	def back
        request.env["rack.session"][:referer]
    end

    def init_referer #previous page!
    	ref=request.env["HTTP_REFERER"]
    	request.env["rack.session"][:referer] =  ref if ref #and !(ref =~ /\/auth\/?/)
		##puts "referer"; p request.env["rack.session"][:referer]
    end

    def init_http_host #previous page!
        request.env['rack.session'][:http_host]=request.env['HTTP_HOST'] unless request.env['rack.session'][:http_host]
    end

    def jsonp_protected(content,callback)
        callback ? callback+"("+content+");" : content
    end

end

unless $dyndoc_web[:local]
    require 'omniauth'
    require 'omniauth-google-oauth2'
    require 'omniauth-twitter'
    require 'omniauth-facebook'
    require 'omniauth-dropbox'
end
require 'fileutils'
require 'redis/objects'
require 'redis/set'
require 'redis/hash_key'
require 'json'
require 'faster_csv'

## see https://code.google.com/apis/console 


module DyndocLogin


	## redis standalone!
	@@users={
		:id 	=> Redis::Set.new('user_ids'),
        :pub    => Redis::HashKey.new('user_public'),
		:info 	=> Redis::HashKey.new('user_infos'),
		:uid 	=> Redis::HashKey.new('user_uids'),
		:mode 	=> Redis::HashKey.new('user_modes'),
		:by_uid => Redis::HashKey.new('users_by_uids')
	}

	def users
		@@users
	end

	def user?(user)
		@@users[:id].member? user
	end

	def infos
		@@infos
	end

	def add_user
		user=request.env["rack.session"][:user_signin][:id]
        pub=request.env["rack.session"][:user_signin][:pub]
		mode=request.env["rack.session"][:user_signin][:mode]
		uid=request.env["rack.session"][:user_signin][:uid]
		info=request.env["rack.session"][:user_signin][:info]
		return :used_id if user? user
		return :used_room if File.exists? user_root(user)
		return :used_uid if @@users[:by_uid].all.keys.include? mode+":"+uid
		FileUtils.mkdir_p user_root(user)
		@@users[:id] << user
        @@users[:pub][user]= pub
		@@users[:mode][user]= mode
		@@users[:uid][user]= uid
		@@users[:info][user]= info
		@@users[:by_uid][mode+":"+uid]=user #to test the uniqueness of the uuid
        FileUtils.mkdir_p public_world_root(pub) unless File.exists? public_world_root(pub)
        FileUtils.mkdir_p public_site_root(pub) unless File.exists? public_site_root(pub)
		return :free_id
	end

    def update_user(value,type)
        user=request.env["rack.session"][:user_login][:id]
        pub=request.env["rack.session"][:user_login][:pub]
        mode=request.env["rack.session"][:user_login][:mode]
        uid=request.env["rack.session"][:user_login][:uid]
        info=request.env["rack.session"][:user_login][:info]
        case type
        when :user
            ## create as a new user
            @@users[:id] << value
            @@users[:mode][value]= mode
            @@users[:uid][value]= uid
            @@users[:info][value]= info
            ## rename the room name
            FileUtils.mv user_root(user),user_root(value)
            ## update
            @@users[:by_uid][mode+":"+uid]=value
            request.env["rack.session"][:user_login][:id]=value
            ## delete the old user
            @@users[:id].delete user
            @@users[:mode].delete user
            @@users[:uid].delete user
            @@users[:info].delete user
            dyndoc_globvar("session.id",value) 
            dyndoc_globvar("userid",value) 
            return true
        when :pub
            if value != @@users[:pub][user]
                #update world root
                if pub and File.exists? public_world_root(pub)
                    FileUtils.mv public_world_root(pub), public_world_root(value)
                end
                FileUtils.mkdir_p public_world_root(value) unless File.exists? public_world_root(value)

                # update site root
                if pub and File.exists? public_site_root(pub)
                    FileUtils.mv public_site_root(pub), public_site_root(value)
                end
                FileUtils.mkdir_p public_site_root(value) unless File.exists? public_site_root(value)

                @@users[:pub][user]= value 
                request.env["rack.session"][:user_login][:pub]=value
                dyndoc_globvar("session.pub",value)
            end
            return true
        when :mode
            # value is a hash here!
            unless mode+":"+uid == value[:mode]+":"+value[:uid]
                ## delete first the old stuff
                @@users[:by_uid].delete mode+":"+uid
                ## the updated stuff
                @@users[:mode][user]= value[:mode]
                @@users[:uid][user]= value[:uid]
                @@users[:info][user]= value[:info]
                request.env["rack.session"][:user_login][:uid]=value[:uid]
                request.env["rack.session"][:user_login][:info]=value[:info]
                @@users[:by_uid][value[:mode]+":"+value[:uid]]=user #to test the uniqueness of the uuid
                return true
            end
        end
        return false
    end

	def del_user

	end

	## rack session!
    def current_user_init(opts=nil)
        if opts
        	opts.each_key{|key| request.env['rack.session'][:user_login][key]=opts[key]}
            request.env['rack.session'][:current_file]=nil
            request.env['rack.session'][:current_pdf]=nil
        else
	        request.env['rack.session'][:user_login]={:id=>"",:pub=>"",:uid=>"",:mode=>"",:info=>{}} unless request.env['rack.session'][:user_login]
            request.env['rack.session'][:current_file]="" unless request.env['rack.session'][:current_file]  
            request.env['rack.session'][:current_pdf]="" unless request.env['rack.session'][:current_pdf]     
            dyndoc_globvar("userid",user_authorized?  ? public_user : "") 
            puts "userid dyndocvar <<"+dyndoc_globvar("userid")+">>"
            p request.env['rack.session'][:user_login]
		end
    end

    def login_uid
        ##p request.env['rack.session'][:user_uid]
        request.env['rack.session'][:user_login][:uid]
    end

    def login_user
         $dyndoc_web[:local] ? "local.user" : request.env['rack.session'][:user_login][:id]
    end

    def logout? #is it working????
        user_root==user_root("")
    end

    def user_root(user=login_user)
    	user.empty? ? "#{$dyndoc_web[:root]}#{$dyndoc_web[:public_rooms]}" : "#{$dyndoc_web[:root]}#{$dyndoc_web[:public_rooms]}/#{user}"
    end

    def user_filename(filename=nil)
    	File.join(user_root,filename[0,1]=="/" ? filename[1..-1] : filename)
    end

    def user_filename!(filename=nil)
        file=user_filename(filename)
        return file if File.exists? file
        filename= (filename[0,1]=="/" ? filename[1..-1] : filename)
        file=Dir[File.join(user_root,"**",filename)]
        file=file.flatten.sort_by{|e|
            res=e.split("/").length.to_f + ("0."+(Time.now - File.mtime(e)).to_i.to_s).to_f
            #p res
            res
        }
        file.empty? ? user_filename(filename) : file[0]
    end

    def user_local_filename(filename) #todo: change local to relative
        p [/^#{user_root}\/(.*)/,filename]
    	(filename =~ /^#{user_root}\/(.*)/) ? $1 : nil 
    end

    def public_user
        ## used now to invite people! No more used as a public prefix for world deployment
        $dyndoc_web[:local] ? login_user : request.env['rack.session'][:user_login][:pub]
    end

    def public_root
        "#{$dyndoc_web[:root]}#{$dyndoc_web[:public_path]}"
    end

    def public_world_root(user=login_user)
        user.empty? ? "#{$dyndoc_web[:root]}#{$dyndoc_web[:public_world]}" : "#{$dyndoc_web[:root]}#{$dyndoc_web[:public_world]}/#{user}"
    end

    def public_site_root(user=login_user)
        user.empty? ? "#{$dyndoc_web[:root]}#{$dyndoc_web[:public_site]}" : "#{$dyndoc_web[:root]}#{$dyndoc_web[:public_site]}/#{user}"
    end

    def public_rsrc_root(user=login_user)
        user.empty? ? "#{$dyndoc_web[:root]}#{$dyndoc_web[:public_rsrc]}" : "#{$dyndoc_web[:root]}#{$dyndoc_web[:public_rsrc]}/#{user}"
    end

    def public_filename(filename=nil,type=:world)
        File.join(
            case type
            when :world
                public_world_root
            when :site
                public_site_root
            when :public
                public_root
            else
                public_root
            end,
        filename)
    end

    def public_relative_filename(filename)
        #(filename =~ /^\/export\/cqlsWeb\/public\/(.*)/) ? $1 : nil
        (filename =~ /^#{$dyndoc_web[:root]}#{$dyndoc_web[:public_path]}\/(.*)/) ? $1 : nil
        
    end

    def public_user_relative_filename(filename)
        user=login_user
        p user
        #(user and filename =~ /^\/export\/cqlsWeb\/public\/site\/(?:#{user})?\/?(?:Home|Projects)?\/?(.*)/) ? $1 : nil
        (user and filename =~ /^#{$dyndoc_web[:root]}#{$dyndoc_web[:public_site]}\/(?:#{user})?\/?(?:Home|Projects)?\/?(.*)/) ? $1 : nil
    end

    def world_filename(filename=nil)
        File.join(public_world_root,filename)
    end

    def site_filename(filename=nil)
        File.join(public_site_root(""),filename)
    end

    def world_real_filename(filename)
        base=filename.split(".")
        ext=base[-1]
        base=base[0...-1].join(".")
        world=case ext.to_sym
        when :dyn_tex
            public_filename(base+".pdf")
        when :dyn_html, :html #, :dyn_ttm, :dyn_txtl
            public_filename(filename)
        else
            nil
        end
        puts world
        world
    end

    def site_real_filename(filename)
        base=filename.split(".")
        ext=base[-1]
        base=base[0...-1].join(".")
        world=case ext.to_sym
        when :dyn_tex
            public_filename(base+".pdf",:site)
        when :dyn_html, :html #, :dyn_ttm, :dyn_txtl
            public_filename(filename,:site)
        else
            nil
        end
    end



    def world_relative_filename(filename)
        (filename =~ /^#{public_world_root}\/(.*)/) ? $1 : nil
    end

    def world_update_link(filename,state)
        world_file=world_real_filename(filename)
        if File.exists? world_file 
            if state=="0"
                FileUtils.rm world_file
                return "0"
            end
        else
            if (state=="1" and (relative_file=world_relative_filename(world_file)))
                unless File.exists? (dir=File.dirname(world_file))
                    p dir
                    FileUtils.mkdir_p dir 
                end
                FileUtils.ln_s user_filename(relative_file), world_file
                return "1"
            end
        end
        return state=="1" ? "0" : "1"  #no action performed! return the old state!
    end

    def dropbox_user_root(user=login_user)
        user.empty? ? "#{$dyndoc_web[:root]}/public/Dropbox" : "#{$dyndoc_web[:root]}/public/Dropbox/#{user}"
    end

    def private_user_root(user=login_user)
        user.empty? ? "/home/cqls/DyndocVB/SharedFolder/Dyndoc" : "/home/cqls/DyndocVB/SharedFolder/Dyndoc/#{user}"
    end


    def user_authorized?
=begin
    	puts "authorized?"
    	p request.env['rack.session'][:user_login]
    	p login_user
    	p login_uid
    	p @@users[:uid].all
    	p @@users[:uid][login_user]
=end
        $dyndoc_web[:local] or login_uid == @@users[:uid][login_user]
    end

    def render_safe(page,engine: :dyn_html,layout: "layout/base.dyn".to_sym,**options)
        if user_authorized?
            puts "#{page.inspect}-> authorized!"
            render page, engine: engine, layout: layout
        else
        	redirect "/auth"
            #puts page+"-> UNauthorized!"
            #inline! "<h2>You need to sign in first if you want to use this service!</h2>", :dyn , :layout=>"demo/layout/R_cqls.dyn" 
        end
    end

    def inline_safe(data,opts={engine: :dyn,:layout=>"demo/layout/R_cqls.dyn"})
        if user_authorized?
            puts "inline -> authorized!"
            render data, type, opts
        else
            redirect! "/auth"
            #puts page+"-> UNauthorized!"
            #inline! "<h2>You need to sign in first if you want to use this service!</h2>", :dyn , :layout=>"demo/layout/R_cqls.dyn" 
        end
    end

    ## page[:dest]= file or directory!
    def build_static_page(page,engine: 'dyn_html', layout: "layout/base.dyn".to_sym, locals: render_defaults[:locals], **opts)
        html_page=page[:src].split(".")[0...-1].join(".")+".html"
        puts "page";p page;p user_local_filename(html_page)
        page[:dest]=html_page unless page[:dest]
        page[:dest]=File.join(page[:dest],user_local_filename(html_page)) if File.directory? page[:dest]
        # init step
        ##puts "build_static: init step"
        curDir=FileUtils.pwd
        FileUtils.cd File.dirname(page[:src])
        # content
        p page[:src].to_sym
        content=render page[:src].to_sym,  engine: engine, layout: layout, locals: locals
        # finalization step
        FileUtils.cd curDir
        $curDyn.tmpl.clean_as_is(content)
        # put content in the target file
        ##puts "built static: #{page[:src]} -->  #{page[:dest]}";#p content
        mkdir_p File.dirname(page[:dest]) unless File.directory? File.dirname(page[:dest])
        File.open(page[:dest],"w") do |f|
            f << content
        end 
    
        if opts[:world_mode] #this part has an equivalent in acEditor_dyndoc.js to fire the resulting html page

            site_path=dyndoc_globvar("document.site_relative_path")
            #puts "world_mode";p opts[:world_mode];p page[:dest]
            site_path=File.dirname(public_user_relative_filename(page[:dest])) unless site_path        
            ##p site_path
            site_path=site_path[1..-1] if site_path[0,1]=="/"
            site_path=public_filename(site_path)
            site_path=File.join(site_path,File.basename(page[:dest])) unless site_path =~ /\.(?:xml|html|htm)$/
            site_path=File.expand_path(site_path)
            mkdir_p File.dirname(site_path) unless File.directory? File.dirname(site_path)
            FileUtils.cp page[:dest],site_path
            ##puts "built static: #{page[:dest]} -->  #{site_path}"
            return site_path

        else
            # IMPORTANT: links inside can be relative since for an authorized user relative links are completed!
            return page[:dest]
        end
    end

    def guest_authorized?
        request.env["rack.session"][:guest_user]
    end

    def render_guest!(page,engine: 'dyn_html', layout: "demo/layout/R_cqls.dyn".to_sym, locals: render_defaults[:locals]) #, **opts)
        if guest_authorized?
            puts page+"-> guest!"
            request.env["rack.session"].delete :guest_user #just once!!!
            render page, engine: engine, layout: layout, locals: locals
        else
            redirect! "/auth"
            #puts page+"-> UNauthorized!"
            #inline! "<h2>You need to sign in first if you want to use this service!</h2>", :dyn , :layout=>"demo/layout/R_cqls.dyn" 
        end
    end

    def mkdir_p(dir)
        dir=File.readlink dir if File.symlink? dir
        FileUtils.mkdir_p dir
    end

    def dir_symlink(dir,link)

        # remove the symlink if existing
        FileUtils.rm link if File.exists? link and File.symlink? link
        # create the symlink
        FileUtils.ln_s dir,link

    end

    def check_user_dir #once the user first connected!

        p "check_user_dir"
        # run over private local VBShare directory

        ## IMPORTANT: No more working now???
        # if (File.directory? private_user_root) and !(File.directory? dropbox_user_root)

        #     dir_symlink File.join(private_user_root,"rooms"),File.join(user_root,"Home")
        #     dir_symlink File.join(private_user_root,"site"),File.join(public_site_root,"Home")

        # end

        # run over all Dyndoc directory

        Dir.glob(File.join(dropbox_user_root(""),"*")) { |dir|

            #p dir

            #p File.exists? File.join(dir,"projects")
            #p File.directory? dir

            if File.directory? dir

                if dir==dropbox_user_root

                    dir_symlink File.join(dir,"rooms"),File.join(user_root,"Home")
                    dir_symlink File.join(dir,"site"),File.join(public_site_root,"Home")

                elsif File.exists? File.join(dir,"members") 
                    members=File.read(File.join(dir,"members")).strip.split(",").map{|u| u.strip}
                    if members.include? login_user
                        prjname=File.basename(dir)
                        dir_symlink File.join(dir,"rooms"),File.join(user_root,prjname)
                        dir_symlink File.join(dir,"site"),File.join(public_site_root,prjname)
                    end
                end
                if File.exists? File.join(dir,"projects") 
                    puts "FILE projects exists for ";p dir;p File.read(File.join(dir,"projects"))
                    File.read(File.join(dir,"projects")).strip.split("\n").map{|u| u.strip.split(":")}.each do |prjPath,prjUsers|
                        if prjUsers.split(",").map{|e| e.strip}.include? login_user
                            userName=File.basename(dir)
                            prjname=File.basename(prjPath)
                            dir_symlink File.join(user_root(userName),prjPath),File.join(user_root,"Projects",prjname)
                            dir_symlink File.join(public_site_root(userName),prjPath),File.join(public_site_root,"Projects",prjname)
                        end
                    end
                end
            end  

        }



    end

    def user_dir(id="0",filter=[:js,:html,:tex,:dyn,:dyn_cfg,:dyn_tex,:dyn_html,:pdf,:png,:gif,:jpg,:jpeg,:RData,:csv,:R,:r,:rb]) #,:dyn_ttm,:dyn_txtl])
    	res=""
    	cur=FileUtils.pwd
    	FileUtils.cd (root=File.join(user_root,(id=="0" ? "" : id)))
        puts "dropbox icon?"
        # p root
        # p (File.symlink? root)
        # if File.symlink? root
        #     p File.readlink root 
        #     p ((File.readlink root) =~ /#{dropbox_user_root("")}/)
        # end
        if ((File.symlink? root) and ((File.readlink root) =~ /#{dropbox_user_root("")}/ or (File.readlink root) =~ /#{private_user_root("")}/)) 
            openFolder,closedFolder='dropbox.ico','dropbox.ico'
        else
            openFolder,closedFolder='folderOpen.gif','folderClosed.gif'
        end
        openids=user_current_openids
        openids=(openids ? openids.split(",") : [])
        openid=openids.include? id
        #puts "public_user";p public_user
        #puts "login_user";p login_user
        if public_user==login_user
            guest_prjs=:all 
        else
            guest_prjs=guest_authorized_dirs
            guest_prjs=(guest_prjs ? guest_prjs.split(",").map{|prj| prj.strip[1..-1].split("/")} : :nothing) 
        end
    	res << "{id: '#{id}'"+(id=="0" ? ",item: [ {id: '/',text: 'Rooms', child: 1, im1: '#{openFolder}', im0: '#{closedFolder}', im2: '#{closedFolder}', open: true  " : ",text: '#{File.basename(id)}', child: 1, im1: '#{openFolder}', im0: '#{closedFolder}', im2: '#{closedFolder}', open: #{openid}  " )+",item: [\n"
    	dir=Dir["*"].sort
    	dir.each_with_index{|f,i|
    		child_id=(id=="0" ? f : File.join(id,f))
            child_id_path=child_id.split("/")
            ## when guest mode, guest_prjs and child_id  have to start the same to be selected  
            next if guest_prjs==:nothing or (guest_prjs!=:all and  guest_prjs.map{|guest_prj| l=[child_id_path.length,guest_prj.length].min;child_id_path[0,l]!=guest_prj[0,l]}.all?)
    		if File.directory? f
    			res << user_dir(child_id)
    			res << (i==dir.length-1 ? "" : ",")+"\n"
    		else
                ext=f.split(".")[-1].to_sym
    			if (filter.include? ext) and !(File.symlink? f)
                    world= [:dyn_html,:dyn_tex].include? ext #:dyn_ttm,:dyn_txtl
    				res <<  "{id: '#{child_id}', text: '#{f}'"+(world ? ", checked: '1'" : ", nochecbox: true")+"}" 
    				res << (i==dir.length-1 ? "" : ",")+"\n"
    			end
    		end
    		
    	}
    	res <<  "]}" + (id=="0" ? "]}" : "")
    	FileUtils.cd cur
    	res
    end

    def user_world_dir(id="0",filter=[:html,:dyn_tex,:dyn_html]) #:dyn_ttm,:dyn_txtl
        cur=FileUtils.pwd
        FileUtils.cd File.join(user_root,(id=="0" ? "" : id))
        dir=Dir["*"]
        ## collect the wold files!
        res=[]
        dir.each_with_index{|f,i|
            child_id=(id=="0" ? f : File.join(id,f))
            if File.directory? f
                res += user_world_dir(child_id)
            else
                ext=f.split(".")[-1].to_sym
                if (filter.include? ext) and !(File.symlink? f)
                    res <<  child_id
                end
            end
        }
        FileUtils.cd cur
        ## write only 
        if id=="0"
            res=res.map{|elt|
                #puts "world";p elt
                world_file=world_real_filename(elt)
                #p  world_file
                world=File.exists? world_file
                "{id: '#{elt}', text: '#{public_relative_filename(world_file)} (from #{elt})', checked: #{world}}" 
            }.join(",\n")
            res="{id: '#{id}', item: [\n"+res+"\n]}"
        end
        res
    end

    def guest_authorized_dirs(dirs=nil)
        if dirs
            request.env['rack.session'].delete :guest_authorized_dirs ##very important to update right now!
            request.env['rack.session'][:guest_authorized_dirs]=dirs #and then modifiy it! 
        else
            request.env['rack.session'][:guest_authorized_dirs]
        end
    end

    def user_current_openids(openids=nil)
        if openids
            request.env['rack.session'].delete :current_openids ##very important to update right now!
            request.env['rack.session'][:current_openids]=openids #and then modifiy it! 
        else
            request.env['rack.session'][:current_openids] ##? request.env['rack.session'][:current_openids] : "" 
        end
    end

    def user_current_file(file=nil)
    	if file
    		if File.exists? (cur_file=File.join(user_root,file))
    			## puts "cur_file=#{cur_file}"
    			request.env['rack.session'].delete :current_file ##very important to update right now!
    			request.env['rack.session'][:current_file]=file #and then modifiy it!
    			##puts "new session[current_file]="+request.env['rack.session'][:current_file]
    			##puts "user_current_file";p request.env['rack.session']
    			##p request.cookies['rack.session']
    		end 
    	else
    		request.env['rack.session'][:current_file] ? request.env['rack.session'][:current_file] : "" 
    	end
    end

    def user_current_pdf(pdf=nil)
        if pdf
            if File.exists? (cur_pdf=File.join(user_root,pdf))
                ## puts "cur_pdf=#{cur_pdf}"
                request.env['rack.session'].delete :current_pdf ##very important to update right now!
                request.env['rack.session'][:current_pdf]=pdf #and then modifiy it!
            end 
        else
            request.env['rack.session'][:current_pdf] ? request.env['rack.session'][:current_pdf] : "" 
        end
    end

    def user_current_theme(th=nil)
        if th
            request.env['rack.session'].delete :current_theme ##very important to update right now!
            request.env['rack.session'][:current_theme]=th #and then modifiy it! 
        else
            request.env['rack.session'][:current_theme] ? request.env['rack.session'][:current_theme] : "0" 
        end
    end


    def user_size(digit=2)
        (`du -sb #{user_root}`.split("\t")[0].to_f/1024.0/1024.0*(10**digit)).round/(10.0**digit)
    end

end

module DyndocCSVFile

    def csv_new(file,varnames,col_sep=";")
        FasterCSV.open(file, "w",:col_sep => col_sep) do |csv|
            csv << varnames
        end
    end

    def csv_datatable(file,col_sep=";")
        csv_table=FasterCSV.table(file,:col_sep => col_sep).to_a
        # add an id at the first column (useful for editable)
        csv_table[1..-1].each_with_index.map { |x,i| [i.to_s]+x }
    end

    def csv_addrow(file,new_row,col_sep=";")   
        FasterCSV.open(file, "a",:col_sep=>col_sep) do |csv|
            csv << new_row
        end
    end
         

    def csv_updatecell(file,i,var,value,col_sep=";")
        csv_table=FCSV.read(file,:col_sep => col_sep, :headers => true) #a table
        i=i.to_i
        var=var.to_s
        p [i,var,csv_table[i],csv_table[i][var],value]
        if csv_table[i.to_i][var]!=value
            csv_table[i][var]=value
            p csv_table.to_csv(:col_sep=>col_sep)
            File.open(file,"w") do |f|
                f << csv_table.to_csv(:col_sep=>col_sep)
            end
        end
    end

end
