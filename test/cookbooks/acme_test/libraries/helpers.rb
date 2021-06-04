def make_password(password)
  require 'bcrypt'
  BCrypt::Password.create(password)
end
