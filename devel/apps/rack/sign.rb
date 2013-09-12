class DyndocSign < Renee::Application

	app {

		path '/in' do
			get{
				if user_authorized?
					redirect! "/admin"
				else
					request.env["rack.session"][:auth_mode]=:signin
					render_guest! "signin.dyn", :dyn
				end
			}

		end

		path '/user' do
			post {
				userid=request.params['update_value']
				if user? userid or !(userid=~/^[\d,a-z,A-Z]*/)
					halt "__not_free__"
				else
					halt userid
				end
			}
		end

		path '/public_user' do
			post {
				pub=request.params['update_value']
				if users[:pub].keys.include? pub or !(pub=~/^[\d,a-z,A-Z]*/)
					halt "__not_free__"
				else
					halt pub
				end
			}
		end

		path '/mode' do
			post {
				userid,userpub,mode=request.params['id'].strip,request.params['pub'].strip,request.params['mode'].strip
				request.env["rack.session"][:user_signin]={:id=>userid,:pub=>userpub,:mode=>mode}
				case mode
				when "google"
					halt "google_oauth2"
				when "facebook","twitter"
					halt mode
				end
			}
		end

		path '/done' do
			get {
				user=request.env["rack.session"][:user_signin][:id] || request.env["rack.session"][:user_login][:id]
				pub=request.env["rack.session"][:user_signin][:pub] || request.env["rack.session"][:user_login][:pub]
				mode=request.env["rack.session"][:user_signin][:mode] || request.env["rack.session"][:user_login][:mode]
				info=request.env["rack.session"][:user_signin][:info] || request.env["rack.session"][:user_login][:info]
				html="
				<h3>Congratulations your account is now created! Click now on the login button below!</h3>
				<td><table cellspacing='0' cellpadding='2' border='0'>
				<tr><td><div><b>User name: </b></td> <td>#{user}</div></td></tr>
				<tr><td><div><b>Public name: </b></td> <td>#{pub}</div></td></tr>
				<tr><td><div><b>User mode: </b></td> <td>#{mode}</div></td></tr>
				<tr><td><div><b>User email: </b></td> <td> #{info['email']}</div></td></tr>
				<tr><td></td><td></td></tr>
				<tr><td><a href='/login'><button>Login</button></a></td><td></td></tr>
				</table></td>
				"
				request.env["rack.session"].delete :user_signin #clear the signin info
				inline! html, :dyn
			}
		end

		path '/admin' do
			get {
				dyndoc_globvar("session.id",request.env["rack.session"][:user_login][:id])
				pub=request.env["rack.session"][:user_login][:pub] || request.env["rack.session"][:user_login][:id]
				dyndoc_globvar("session.pub",pub)
				mode=request.env["rack.session"][:user_login][:mode]
				mode= request.env["rack.session"][:user_login][:info]["email"] if request.env["rack.session"][:user_login][:info]["email"]
				dyndoc_globvar("session.mode",mode)
				request.env["rack.session"][:auth_mode]=:admin
				render_safe! "admin.dyn", :dyn
			}

			path 'user' do
				post {
					puts "admin/user"
					user=request.params["id"]
					puts user
					halt update_user(user,:user) ? "true" : "false"
				}
			end

			path 'pub' do
				post {
					puts "admin/pub"
					pub=request.params["pub"]
					puts pub
					halt update_user(pub,:pub) ? "true" : "false"
				}
			end

			path 'mode' do
				post {
					puts "admin/mode"
					mode=request.params["mode"].strip
					puts mode
					request.env["rack.session"][:user_signin]={:mode=>mode}
					case mode
					when "google"
						halt "google_oauth2"
					when "facebook","twitter"
						halt mode
					end
				}
			end

		end

	}.setup {
  		views_path File.join($dyndoc_web[:devel_path],"views") #File.expand_path('../../../views', __FILE__)
    	include DyndocRenee
    	include DyndocLogin
    	default_layout "demo/layout/R_cqls.dyn"
	}

end