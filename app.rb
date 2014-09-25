require "sinatra"
require "data_mapper"
require "pony"

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/contact.db")

enable :sessions

helpers do
  def base_url
    @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
  end

  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == ['admin', 'admin']
  end
end

class User
  # This will help map this class to a table in the 
  # database we connected to above.
  # The table name will be users
  include DataMapper::Resource

  property :id, Serial
  property :first_name, String
  property :last_name, String
  property :email, String
  property :urgent, Boolean
  property :message, Text
  property :phone_number, String
  property :created_at, DateTime

end

DataMapper.finalize

DataMapper.auto_upgrade!

get "/" do
  session[:visits] ||= 0
  session[:visits] += 1
  erb :index, layout: :default_layout
end

get "/hello" do
  erb :hello, layout: :default_layout
end

get "/contact" do
  erb :contact, layout: :default_layout
end

get "/bg_color/:color" do |color|
  uri = request.env["HTTP_REFERER"].gsub(base_url, "")
  session[:visits] -= 1 if uri == "/"
  session[:color] = color
  redirect back
end

get "/all_contacts" do
  protected!
  @users = User.all
  erb :all_contacts, layout: :default_layout
end

post "/contact" do
  User.create({
      first_name: params[:first_name],
      last_name:  params[:last_name],
      email:      params[:email],
      urgent:     (params[:urgent] == "on"),
      message:    params[:message],
      created_at: Time.now
    })
  full_name = "#{params[:first_name]} #{params[:last_name]}"
  Pony.mail(to: "tam@codecore.ca",
            from: params[:email],
            subject: "You've got a contact",
            body: "#{full_name} contact you: #{params[:message]}",
            via: :smtp,
            via_options: {
              address: "smtp.gmail.com",
              port: "587",
              enable_starttls_auto: true,
              user_name: "answerawesome",
              password: "Sup3r$ecret",
              authentication: :plain,
              domain: "gmail.com"
            })
  @name = params[:first_name]
  erb :thank_you, layout: :default_layout
end

get "/contacts/:id" do |id|
  protected!
  @user = User.get id
  session[:user_name] = @user.first_name
  erb :single_contact, layout: :default_layout
end


