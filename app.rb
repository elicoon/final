# Set up for the application and database. DO NOT CHANGE. #############################
require "sinatra"                                                                     #
require "sinatra/reloader" if development?                                            #
require "sequel"                                                                      #
require "logger"                                                                      #
require "twilio-ruby"                                                                 #
require "bcrypt"
require "httparty"
require "time"
require "sinatra/cookies"
require "geocoder" 
require "forecast_io"                                                                       #
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
# before do
#     @current_user = users_table.where(id: session["user_id"]).to_a[0]
# end

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
        @user_city=params["inputCity"]
        @user_state=params["inputState"]
        @user_zip=params["inputZip"]

            #separating user entries into individual arrays of words and combining the arrays
            @ad_line1_array = @ad_line1.split(/\W+/)
            @full_ad_array = @ad_line1_array << @user_city << @user_state << @user_zip

            @address_cookie = "#{@full_ad_array.join(" ")}"
            cookies["address"] = "#{@address_cookie}"

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
        redirect "polling_locations/#{@existing_polling_location[:id]}" 
    else
        polling_locations_table.insert(
            polling_name: "New polling location",
            polling_address: "#{@poll_place_address_line1}"
        )
        #doing this because setting a variable equal to the table insert just returns the id, not the full hash
        @new_polling_location = polling_locations_table.where(polling_address: @poll_place_address_line1).to_a[0]

        puts "#{@new_polling_location} this is the text to reference"
        if @new_polling_location
            redirect "polling_locations/#{@new_polling_location[:id]}" 
        end
    end
end


get "/polling_locations/:id" do
    puts "params: #{params}"

    @my_address = cookies["address"]
    @poll = polling_locations_table.where(id: params[:id]).to_a[0]
    cookies["poll_place_id"] = @poll[:id]

    #creating variables for wait times and issues to populate
    @tot_wait_time = polling_times_table.where(polling_location_id:cookies["poll_place_id"]).sum(:line_time)
    @count_wait_times = polling_times_table.where(polling_location_id:cookies["poll_place_id"]).count(:line_time)
    @avg_wait_time = @tot_wait_time/@count_wait_times
    @recent_wait_time = polling_times_table.where(polling_location_id:cookies["poll_place_id"]).order(Sequel.desc(:line_time)).to_a[0]
    @num_issues = polling_issues_table.where(polling_location_id:cookies["poll_place_id"]).count("issue_type")

    #feeding setting up google maps api key
            @googlemaps_sid = ENV["GOOGLE_MAPS_SID"]
            puts "print @my_address #{@my_address}"
            location_search = Geocoder.search(@my_address)
            puts "print location_search variable #{location_search}" 
            lat_long_array = location_search.first.coordinates # => [lat,long]
            puts "print lat_long_array #{lat_long_array}"
            @lat_long = "(#{lat_long_array[0]},#{lat_long_array[1]})"
            puts "print @lat_long #{@lat_long}"

    view "test"
end

post "/polling_locations/:id/time/create" do
    puts "params: #{params}"
    #first, find the polling location we want to create an entry for
    @poll = polling_locations_table.where(id: params[:id]).to_a[0]
    @my_address = cookies["address"]

    polling_times_table.insert(
        polling_location_id: @poll[:id],
        voter_address: cookies["address"],
        line_time: params["line_time"],
        date_time_reported: Time.now.to_i
    )
    
    @tot_wait_time = polling_times_table.where(polling_location_id:cookies["poll_place_id"]).sum(:line_time)
    @count_wait_times = polling_times_table.where(polling_location_id:cookies["poll_place_id"]).count(:line_time)
    @avg_wait_time = @tot_wait_time/@count_wait_times
    @recent_wait_time = polling_times_table.where(polling_location_id:cookies["poll_place_id"]).order(Sequel.desc(:date_time_reported)).to_a[0]
    @num_issues = polling_issues_table.where(polling_location_id:cookies["poll_place_id"]).count("issue_type")
    
    #feeding setting up google maps api key
            @googlemaps_sid = ENV["GOOGLE_MAPS_SID"]
            location_search = Geocoder.search(@my_address)
            puts "print location_search variable #{location_search}" 
            @lat_long = location_search.first # => [lat,long]
            puts "print @lat_long #{@lat_long}"

    view "test"
end

post "/polling_locations/:id/issue/create" do
    puts "params: #{params}"
    #first, find the polling location we want to create an entry for
    @poll = polling_locations_table.where(id: params[:id]).to_a[0]
    @my_address = cookies["address"]

    polling_issues_table.insert(
        polling_location_id: @poll[:id],
        voter_address: cookies["address"],
        issue_type: params["issue_type"],
        issue_text: params["issue_details"],
        date_time_reported: Time.now.to_i
    )

    @tot_wait_time = polling_times_table.where(polling_location_id:cookies["poll_place_id"]).sum(:line_time)
    @count_wait_times = polling_times_table.where(polling_location_id:cookies["poll_place_id"]).count(:line_time)
    @avg_wait_time = @tot_wait_time/@count_wait_times
    @recent_wait_time = polling_times_table.where(polling_location_id:cookies["poll_place_id"]).order(Sequel.desc(:date_time_reported)).to_a[0]
    @num_issues = polling_issues_table.where(polling_location_id:cookies["poll_place_id"]).count("issue_type")

    #feeding setting up google maps api key
            @googlemaps_sid = ENV["GOOGLE_MAPS_SID"]
            location_search = Geocoder.search(@my_address)
            puts location_search 
            @lat_long = location_search.first # => [lat,long]
            puts @lat_long

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

