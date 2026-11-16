class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Users 0.32 adds Devise confirmable and refuses password sign-in until
  # confirmed_at is set. Dummy accounts are created already confirmed.
  before_create :skip_confirmation!, if: -> { respond_to?(:skip_confirmation!) }
end
