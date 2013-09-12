class DyndocAuth < Scorched::Controller
        include DyndocLogin
        include DyndocRenee
        render_default.marge!
            dir: File.expand_path('../../../views', __FILE__),
            engine: :dyn,
            layout: "demo/layout/R_cqls.dyn"
    
        get "/" {
            request.env["rack.session"][:auth_mode]=:login
            account=request.params['account'] || 'username'
            size=[account.split(":")[0].length,20].max
            code="
            <h3>To login, only enter your account username</h3>
            <input id='login-user' type='text' value='#{account}' size='#{size}'/>
            <h4>Notice that you need to be introduced by an already registered user!</h4>
            <!-- a href='/sign/in'><button>Sign in!</button></a -->
            <script>

            $('#login-user').keypress(function(event) {
                 if (event.keyCode == '13') { 
                    $.post('/auth/mode',{id: $('#login-user').val(), autologin: false},
                    function(mode) {
                        if(mode=='__SignUp__') {
                            $(window.location).attr('href', '/sign/in'); //to redirect to the account page!
                        } 
                        else if(mode=='__DropboxUser__') {
                            $(window.location).attr('href', '/dev'); //to redirect to the account page!
                        }
                        else if(mode=='__PrivateUser__') {
                            $(window.location).attr('href', '/dev'); //to redirect to the account page!
                        }
                        else {
                            $(window.location).attr('href', '/auth'+mode); //to redirect to the authentification page!
                        }
                    },
                    'text'
                    )
                }
            });
            </script>
            "
            if request.params['account']
                code += "
                    <script>
                       $.post('/auth/mode',{id: $('#login-user').val(), autologin: true},
                    function(mode) {
                        if(mode=='__SignUp__') {
                            $(window.location).attr('href', '/sign/in'); //to redirect to the account page!
                        } 
                        else if(mode=='__DropboxUser__') {
                            $(window.location).attr('href', '/dev'); //to redirect to the account page!
                        }
                        else if(mode=='__PrivateUser__') {
                            $(window.location).attr('href', '/dev'); //to redirect to the account page!
                        }
                        else {
                            $(window.location).attr('href', '/auth'+mode); //to redirect to the authentification page!
                        }
                    },
                    'text'
                    ) 
                    </script>
                "
            end
            inline! code, :dyn
    	}

        post '/mode' do
                request.env["rack.session"][:auth_mode]=:login if request.params['login'] and request.params['login']=="true"
                userid=request.params['id'].strip
                autologin=eval(request.params['autologin'].strip)
                userid,secret,key=userid.split(":") if userid.include? ":"
                puts "USERID";p userid;p (user? userid)
                if user? userid
                    mode=users[:mode][userid]
                    pub=users[:pub][userid]
                    request.env["rack.session"][:user_login]={:id=>userid,:mode=>mode,:pub=>pub}
                    puts "user login!! ";p request.env["rack.session"][:user_login]
                    case mode
                    when "google"
                        halt "/google_oauth2"
                    when "facebook","twitter","dropbox"
                        halt "/"+mode
                    when "dropboxUser"
                        pub_user,guest_prjs=nil,nil #only for guest identification
                        if (secret.include? "@") and key
                            uid_file=File.join("/export/cqlsWeb/public/Dropbox",userid,"guests")
                            if File.exists? uid_file
                                guest_user,guest_uid=secret,key
                                guest_ok=nil
                                File.read(uid_file).strip.split("\n").map {|l|
                                    guest,uid,prjs,host,port=l.split(":")
                                    host += ":" + port if port
                                    puts "http_host";p host
                                    if guest_user==guest and guest_uid==uid
                                        guest_ok=(host ? (host==request.env["HTTP_HOST"]) : true)
                                        guest_prjs=prjs
                                        break
                                    end
                                }
                                if guest_ok
                                    user_uid=users[:uid][userid]
                                    pub_user=guest_user
                                end
                            else
                               user_uid="unknown" 
                            end
                        else
                            uid_file=File.join("/export/cqlsWeb/public/Dropbox",userid,secret)
                            if autologin #wait for Secret file on the server
                                start=Time.now
                                while !(File.exists? uid_file) and (Time.now - start < 15 ) 
                                end
                            end
                            if File.exists? uid_file
                                user_uid=File.read(uid_file)
                                File.unlink uid_file
                            else
                                user_uid="unknown"
                            end
                        end
                        pub_user=userid unless pub_user
                        #puts "user uid";p user_uid
                        #puts "user pub";p pub_user
                        current_user_init(:uid => user_uid, :pub => pub_user,:info => {})
                        #puts "guest_prjs";p guest_prjs
                        guest_authorized_dirs(guest_prjs) if guest_prjs
                        request.env["rack.session"].delete :auth_mode
                        check_user_dir
                        halt "__DropboxUser__"
                    when "privateUser"
                        #only local user!!!!
                        puts "remote addr";p request.env["REMOTE_ADDR"]
                        p secret
                        user_uid=users[:uid][userid] #todo test if local
                        current_user_init(:uid => user_uid, :info => {})
                        request.env["rack.session"].delete :auth_mode
                        check_user_dir
                        halt "__PrivateUser__"
                    else 
                        halt "" ## go back to the auth page!
                    end
            
                else

                    filename,code=userid.split("@")
                    filename=File.join("/export/cqlsWeb/tmp/signup",filename)
                    halt "" unless File.exists? filename
                    if File.read(filename).strip==code
                        request.env["rack.session"][:guest_user]=true
                        halt "__SignUp__"
                    else
                        halt "" ## go back to the auth page!
                    end
                end
        end
            
    	route /(?:google_oauth2|facebook|twitter|dropbox)/ {|auth|
    		
            get "/" { halt "path is auth/#{auth}" }

    		get 'callback' do
                    if request.env["rack.session"][:auth_mode]==:login
                        opts=request.env['omniauth.auth'].to_hash
                        current_user_init(:uid => opts["uid"], :info => opts["info"])
                        request.env["rack.session"].delete :auth_mode
                        check_user_dir
                        redirect! "/"
                    elsif request.env["rack.session"][:auth_mode]==:signin
                        auth_info=request.env['omniauth.auth'].to_hash
                        request.env["rack.session"][:user_signin][:uid]=auth_info["uid"]
                        request.env["rack.session"][:user_signin][:info]=auth_info["info"]
                        puts "add_user:"+request.env["rack.session"][:user_signin].inspect
                        if (status=add_user)==:free_id
                            request.env["rack.session"].delete :auth_mode
                            redirect! "/sign/done"
                        else
                            puts "adding user status: #{status}"
                            dyndoc_globvar("signin_status",status.to_s)
                            redirect! "/sign/in" 
                        end
                    elsif request.env["rack.session"][:auth_mode]==:admin
                        ## to change the authentification mode via admin
                        auth_info=request.env['omniauth.auth'].to_hash
                        request.env["rack.session"][:user_signin][:uid]=auth_info["uid"]
                        request.env["rack.session"][:user_signin][:info]=auth_info["info"]
                        puts "update_user:"+request.env["rack.session"][:user_signin].inspect
                        update_user(request.env["rack.session"][:user_signin],:mode)
                        request.env["rack.session"].delete :auth_mode
                        redirect! "/sign/admin"
                    end
    		end
    	}

    	path  'failure' do
    		get { halt request.env['omniauth.auth'].to_hash.inspect rescue "No Data"}
    	end

        path 'whois' do
            get {
                inline! login_user
            }
        end

        path 'logout' do
            get {
                current_user_init(:id=>"",:pub=>"",:info=>{},:uid=>"",:mode=>"")
                redirect! back
            } 
        end

        path 'unauthorized' do
            get {
                inline! "<h2>You need to sign in first if you want to use this service!</h2>", :dyn , :layout=>"demo/layout/R_cqls.dyn" 
            }
        end
    }
end