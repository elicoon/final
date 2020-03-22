# Set up for the application and database. DO NOT CHANGE. #############################
require "sequel"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB = Sequel.connect(connection_string)                                                #
#######################################################################################

# Database schema
DB.create_table! :polling_locations do
  primary_key :id
  String :polling_name
  String :polling_address
  String :accessible
  String :township
end
DB.create_table! :polling_times do
  primary_key :id
  foreign_key :polling_location_id
  String :voter_address
  Integer :line_time
  String :date_time_reported
end
DB.create_table! :polling_issues do
  primary_key :id
  foreign_key :polling_location_id
  String :voter_address
  String :issue_type
  String :issue_text, text: true
  String :date_time_reported
end
DB.create_table! :users do
  primary_key :id
  String :name
  String :phone
  String :email
  String :password
end

  
# Insert dummy seed data (including issues and times so the program doesn't error out if a poll monitor clicks on one of them)
polling_locations_table = DB.from(:polling_locations)
polling_issues_table = DB.from(:polling_issues)
polling_times_table = DB.from(:polling_times)

polling_locations_table.insert(polling_name: "Polling location 1's name", 
                    polling_address: "Polling location 1's address",
                    accessible: "Yes",
                    township: "Kellogg township")

                    polling_issues_table.insert(
                        polling_location_id: 1,
                        voter_address: "Seed voter address",
                        issue_type: "Seed voter issue type",
                        issue_text: "Seed voter issue text",
                        date_time_reported: Time.now.to_i
                        )

                    polling_times_table.insert(
                        polling_location_id: 1,
                        voter_address: "Seed voter address",
                        line_time: 1,
                        date_time_reported: Time.now.to_i
                        )

polling_locations_table.insert(polling_name: "Polling location 2's name", 
                    polling_address: "Polling location 2's address",
                    accessible: "Yes",
                    township: "Evanston township")

                    polling_issues_table.insert(
                        polling_location_id: 2,
                        voter_address: "Seed voter address",
                        issue_type: "Seed voter issue type",
                        issue_text: "Seed voter issue text",
                        date_time_reported: Time.now.to_i
                        )

                    polling_times_table.insert(
                        polling_location_id: 2,
                        voter_address: "Seed voter address",
                        line_time: 1,
                        date_time_reported: Time.now.to_i
                        )



