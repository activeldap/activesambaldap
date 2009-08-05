# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_asl-admin_session',
  :secret      => 'c926de1eb94a92bebbf93d781f2f9f684dbf873bff2ddd56714478f06c5ea28fd61a2c2140c298d17dde1ee174eed8031001976e329c3911229b1ea26725004c'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
