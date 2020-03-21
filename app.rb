# Set up for the application and database. DO NOT CHANGE. #############################
require "sinatra"                                                                     #
require "sinatra/reloader" if development?                                            #
require "sequel"                                                                      #
require "logger"                                                                      #
require "twilio-ruby"                                                                 #
require "bcrypt"
require "httparty"                                                                    #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB ||= Sequel.connect(connection_string)                                              #
DB.loggers << Logger.new($stdout) unless DB.loggers.size > 0                          #
def view(template); erb template.to_sym; end                                          #
use Rack::Session::Cookie, key: 'rack.session', path: '/', secret: 'secret'           #
before { puts; puts "--------------- NEW REQUEST ---------------"; puts }             #
after { puts; }                                                                       #
#######################################################################################

polling_locations_table = DB.from(:polling_locations)
polling_times_table = DB.from(:polling_times)
polling_issues_table = DB.from(:polling_issues)
users_table = DB.from(:users)

#setting the user's session (aka encrypted cookie)
#good to go (I think)
before do
    @current_user = users_table.where(id: session["user_id"]).to_a[0]
end

#enabling Twilio with environmental variables
#NEEDTOFIX -> 
    #specify correct route
    #sign up for twilio account
    #don't be an idiot and push to github with twilio SID
    #set environmental variables in gitpod
    #set environmental variables in heroku
# get '/send_text' do
#     account_sid = ENV["TWILIO_ACCOUNT_SID"]
# end

#homepage note: the homepage here is not actually the index route
get "/" do
    puts "params: #{params}"

#I don't think I need anything here because the news ticker will come from the layout.erb document

view "new_address"
end

#take the user's address submission, bounce it off the google civics API, then decide what to do
get "/polling_location" do
#create a new route here that is taking the user's address and then matching/creating the polling location
puts "params: #{params}"

        #array of the words in the first line. Have to do this because the google civics api is finicky
        @ad_line1=params["ad_line1"]
        @ad_line2=params["ad_line2"]
        @user_city=params["inputCity"]
        @user_state=params["inputState"]
        @user_zip=params["inputZip"]

            #separating user entries into individual arrays of words and combining the arrays
            @ad_line1_array = @ad_line1.split(/\W+/)
            @ad_line2_array = @ad_line2.split(/\W+/)
            @full_ad_array = @ad_line1_array + @ad_line2_array << @user_city << @user_state << @user_zip

            #converting to civic api-friendly format
            @civic_api_address_format = "#{@full_ad_array.join("%20")}"

            #feeding to the google civic api, assuming electionID of 2000
            @googlecivic_sid = ENV["GOOGLE_CIVIC_SID"]
            googleurl="https://www.googleapis.com/civicinfo/v2/voterinfo?address=#{@civic_api_address_format}&electionId=2000&key=#{@googlecivic_sid}"

        response = HTTParty.get(googleurl).parsed_response.to_hash
        @poll_place_address_line1 = response["pollingLocations"][0]["address"]["line1"]
        @full_response = response


    #check if there's already a polling place with this address and adding a new entry to the database if it doesn't find a match
    @existing_polling_location = polling_locations_table.where(polling_address: @poll_place_address_line1).to_a[0]
    if @existing_polling_location
        redirect "polling_locations/#{@existing_polling_location[:id]}" #this is what's currently breaking
        #view "polling_locations/#{@existing_polling_location[:id]}" 
    else
        @new_polling_location = polling_locations_table.insert(
            polling_name: "New polling location",
            polling_address: "#{@poll_place_address_line1}"
        )
        redirect "polling_locations/#{@new_polling_location[:id]}" 
    end
end


#this appears to be broken based based on the errors i'm getting
get "/polling_locations/:id" do
    puts "params: #{params}"

    @poll = polling_locations_table.where(id: params[:id]).to_a
    pp @poll

    view "test"
end

#next, redirect to the show page because now we have the location id
#think of this similarly to the users create from class 10
#one option to keep the variable is to pass it through the URL with q
#another option is to save it as a cookie and set a cookie to the address value

# view "polling_location"
# end

# get "/polling_locations/:id" do
#     puts "params #{params}"

#     @users_table = users_table
#     @polling_location = polling_locations_table.where(id: 

# view



#Polling Place Details, aka "show" route
# get "/polling_locations/:id"
#     puts "params: #{params}"

#     @user_address = params["q"]
    
    #hit the google civics API here to submit the user's address and return an array that includes the relevant pieces of information
    
    # @polling_location_name = #grab the correct part of the google civic api array, the polling location name

    
    #check our polling location database to see if the address exists. If yes, use it. If not, create one and return it.

    #next, use our database to show the polling address, accessibility, and township (note that we could do this through the google API
    #but this way we don't hit the API a bunch of times and potentially run up costs)

    # @polling_location_name = polling_locations_table.where(polling_address: @)
    # @polling_location_address = polling_locations_table.where(polling_name: @polling_location_name).to_a[0]
    # @polling_location_accessible = #need to define
    # @polling_location_township = #need to define

    #next, use geocoder to satisfy assignment requirement
    # location_search = Geocoder.search(@polling_location_address)
    
    #then convert the user's polling place to lat_long so we can feed it into the google maps API to satisfy that part of the requirement
    # @polling_place_lat_long = location_search.first.coordinates # => [lat,long]
    


    # @polling_name = polling_locations_table.where(id: 
    # #need to 
    # )
    # @ = polling_times_table 
    # @ = polling_issues_table

