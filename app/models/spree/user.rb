class Spree::User < ActiveRecord::Base
    has_many :reviews
end