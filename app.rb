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
require "forecast_io"                                                                 #
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
        puts "google civics response is #{response}"

#need a check here to see if google civics had a response. If google civics returned an error, come back with that error


# if response["error"]["message"] == "Failed to parse address"
#     view "address_error"
# else


    @poll_place_address_line1 = response["pollingLocations"][0]["address"]["line1"]
    @full_response = response


    #check if there's already a polling place with this address and adding a new entry to the database if it doesn't find a match
    @existing_polling_location = polling_locations_table.where(polling_address: @poll_place_address_line1).to_a[0]
    if @existing_polling_location
        redirect "polling_locations/#{@existing_polling_location[:id]}" 
    else
        polling_locations_table.insert(
            polling_name: "New polling location",
            polling_address: "#{@poll_place_address_line1}",
            accessible: "No data on accessibility",
            township: "No data on township or precinct"
        )

        #doing this because setting a variable equal to the table insert just returns the id, not the full hash
        @new_polling_location = polling_locations_table.where(polling_address: @poll_place_address_line1).to_a[0]

        #seeding issues for new location to avoid error
        polling_issues_table.insert(
            polling_location_id: @new_polling_location[:id],
            voter_address: "Seed voter address",
            issue_type: "Seed voter issue type",
            issue_text: "Seed voter issue text",
            date_time_reported: Time.now.to_i
        )

        #seeding times for new location to avoid error
        polling_times_table.insert(
            polling_location_id: @new_polling_location[:id],
            voter_address: "Seed voter address",
            line_time: 1,
            date_time_reported: Time.now.to_i
        )

        

        puts "#{@new_polling_location} this is the text to reference"
        if @new_polling_location
            redirect "polling_locations/#{@new_polling_location[:id]}" 
        end
    end
# end
end


get "/polling_locations/:id" do
    puts "params: #{params}"

    @my_address = cookies["address"]
    @poll = polling_locations_table.where(id: params[:id]).to_a[0]
    cookies["poll_place_id"] = @poll[:id]

    #creating variables for wait times and issues to populate
    @tot_wait_time = polling_times_table.where(polling_location_id: params[:id]).sum(:line_time)
    @count_wait_times = polling_times_table.where(polling_location_id: params[:id]).count(:line_time)
    @avg_wait_time = @tot_wait_time / @count_wait_times
    @recent_wait_time = polling_times_table.where(polling_location_id: params[:id]).order(Sequel.desc(:line_time)).to_a[0]
    @num_issues = polling_issues_table.where(polling_location_id: params[:id]).count("issue_type")

    #feeding setting up google maps api key
            @googlemaps_sid = ENV["GOOGLE_MAPS_SID"]
            puts "@my_address is #{@my_address}"
            location_search = Geocoder.search("#{@my_address}")
            puts "location search is #{location_search}"
            lat_long_array = location_search.first.coordinates # => [lat,long]
            @lat_long = "(#{lat_long_array[0]},#{lat_long_array[1]})"
   

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
            lat_long_array = location_search.first.coordinates # => [lat,long]
            @lat_long = "(#{lat_long_array[0]},#{lat_long_array[1]})"

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
            lat_long_array = location_search.first.coordinates # => [lat,long]
            @lat_long = "(#{lat_long_array[0]},#{lat_long_array[1]})"
    view "test"
end



#This is the list of all polling locations for poll monitors
get "/poll_index" do

@polling_locations_table = polling_locations_table.all.to_a
puts "print @polling_locations_table #{@polling_locations_table}"

    view "poll_index"
end

get "/poll_monitor/:id" do

     puts "params: #{params}"


    @poll = polling_locations_table.where(id: params[:id]).to_a[0]

    #creating variables for wait times and issues to populate
    @tot_wait_time = polling_times_table.where(polling_location_id: params[:id]).sum(:line_time)
    @count_wait_times = polling_times_table.where(polling_location_id: params[:id]).count(:line_time)
    @avg_wait_time = @tot_wait_time / @count_wait_times
    @recent_wait_time = polling_times_table.where(polling_location_id: params[:id]).order(Sequel.desc(:line_time)).to_a[0]
    @num_issues = polling_issues_table.where(polling_location_id: params[:id]).count("issue_type")

    @issue_table = polling_issues_table.where(polling_location_id: params[:id])
    @time_table = polling_times_table.where(polling_location_id: params[:id])
   

    view "poll_monitor_show"
end