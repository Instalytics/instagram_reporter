# THIS IS ONLY USED BY THE RAKE TASK FOR AUTOMATING 
# GATHERING OF POPULAR USERS
class InstagramUser
  include Mongoid::Document

  validates :username, uniqueness: true

  field :username,          type: String
  field :email,             type: String
  field :followers,         type: String
  field :bio,               type: String
  field :created_at,        type: DateTime
  field :updated_at,        type: DateTime
  field :already_presented, type: Boolean

  scope :with_email,     nin(email: [nil, ""])
  scope :with_followers, nin(followers: [nil, ""])
  scope :last_24h,       where(:created_at.gt => 1.day.ago)
  scope :last_3_days,    where(:created_at.gt => 3.days.ago).where(:created_at.lt => 1.day.ago)
  scope :last_7_days,    where(:created_at.gt => 7.days.ago).where(:created_at.lt => 1.day.ago)

  def formated_created_at
    self.created_at.strftime('%d-%m-%Y (%H:%M)')
  end

  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << %w(social_media_profile_name followers_count followers_count_short contact_details about_me created_at) 
      all.each do |instagram_user|
        csv << [ instagram_user.username,
                 instagram_user.followers.to_i * 1000,
                 instagram_user.followers,
                 instagram_user.email,
                 instagram_user.bio,
                 instagram_user.created_at
               ]

      end
    end
  end

end
