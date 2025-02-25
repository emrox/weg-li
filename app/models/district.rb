class District < ActiveRecord::Base

  geocoded_by :geocode_address
  after_validation :geocode

  acts_as_api

  api_accessible :public_beta do |template|
    %i(name zip email prefix latitude longitude created_at updated_at).each { |key| template.add(key) }
  end

  validates :name, :zip, :email, presence: :true

  has_many :notices

  def self.from_zip(zip)
    find_by(zip: zip)
  end

  def map_data
    {
      zoom: 13,
      latitude: latitude,
      longitude: longitude,
    }
  end

  def statistics(date = 100.years.ago)
    {
      notices: notices.since(date).count,
      users: User.where(id: notices.since(date).pluck(:user_id)).count,
    }
  end

  def geocode_address
    "#{zip}, #{name}, Deutschland"
  end

  def display_name
    "#{email} (#{zip} #{name})"
  end

  def District.attach_prefix
    District.where(prefix: nil).limit(5000).each do |district|
      prefix = Vehicle.zip_to_prefix[district.zip]
      if prefix.present?
        district.update_attribute(:prefix, prefix)
      else
        Rails.logger.info("no match for #{district.name} #{district.zip}")
      end
    end
  end
end
