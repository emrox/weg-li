class Notice < ActiveRecord::Base
  ADDRESS_ZIP_PATTERN =/.+(\d{5}).+/

  extend TimeSplitter::Accessors
  split_accessor :date

  include Bitfields
  bitfield :flags, 1 => :empty, 2 => :parked, 4 => :hinder, 8 => :parked_three_hours, 16 => :parked_one_hour

  include Incompletable

  attr_accessor :tweet_url

  before_validation :defaults

  geocoded_by :full_address, language: Proc.new { |model| I18n.locale }, no_annotations: true
  after_validation :geocode

  belongs_to :user
  belongs_to :district
  belongs_to :bulk_upload, optional: true
  has_many_attached :photos

  validates :photos, :registration, :charge, :street, :zip, :city, :date, presence: :true
  validates :zip, format: { with: /\d{5}/, message: 'PLZ ist nicht korrekt' }

  enum status: {open: 0, disabled: 1, analyzing: 2, shared: 3}

  scope :since, -> (date) { where('notices.created_at > ?', date) }
  scope :destroyable, -> () { where.not(status: :shared) }
  scope :for_public, -> () { where.not(status: :disabled) }

  def self.for_reminder
    open.joins(:user).where(date: [(21.days.ago.beginning_of_day)..(14.days.ago.end_of_day)]).merge(User.not_disable_reminders)
  end

  def self.from_param(token)
    find_by_token!(token)
  end

  def self.statistics(date = 100.years.ago)
    {
      photos: since(date).joins(photos_attachments: :blob).count,
      all: since(date).count,
      incomplete: since(date).incomplete.count,
      shared: since(date).shared.count,
      users: User.where(id: since(date).pluck(:user_id)).count,
      all_users: User.since(date).count,
      districts: District.count,
    }
  end

  def self.prepared_claim(token)
    Notice.joins(:user).where({ users: { access: :ghost} }).find_by(token: token)
  end

  def duplicate!
    notice = dup
    notice.photos_attachments = photos.map(&:dup)
    notice.registration = nil
    notice.color = nil
    notice.brand = nil
    notice.status = :open
    notice.save_incomplete!
    notice.reload
  end

  def analyze!
    self.status = :analyzing
    save_incomplete!
    AnalyzerJob.set(wait: 3.seconds).perform_later(self)
  end

  def apply_favorites(registrations)
    other = Notice.shared.since(1.month.ago).find_by(registration: registrations)
    if other
      self.registration = other.registration
      self.charge = other.charge
      self.brand = other.brand if other.brand?
      self.color = other.color if other.color?
      self.flags = other.flags if other.flags?
    end
  end

  def similar_count(since: 1.month.ago)
    return 0 if registration.blank?

    @similar_count ||= Notice.since(since).where(registration: registration).count
  end

  def date_doubles
    return false if registration.blank?

    user.notices.where('DATE(date) = DATE(?)', date).where(registration: registration).where.not(id: id)
  end

  def photo_doubles
    user.photos_attachments.joins(:blob).where('active_storage_attachments.record_id != ?', id).where('active_storage_blobs.filename' => photos.map { |photo| photo.filename.to_s })
  end

  def zip
    super || (address || '')[ADDRESS_ZIP_PATTERN, 1]
  end

  def meta
    photos.map(&:metadata).to_json
  end

  def coordinates?
    latitude? && longitude?
  end

  def handle_geocoding
    if coordinates?
      results = Geocoder.search([latitude, longitude])
      if results.present?
        best_result = results.first
        self.zip = best_result.postal_code
        self.city = best_result.city
        self.street = "#{best_result.street} #{best_result.house_number}".strip
      end
    else
      self.city ||= user.city
      geocode
    end
  end

  def full_address
    "#{street}, #{zip} #{city}, Deutschland"
  end

  def map_data
    {
      latitude: latitude,
      longitude: longitude,
      charge: charge,
    }
  end

  def to_param
    token
  end

  private

  def defaults
    self.token ||= SecureRandom.hex(16)
    if zip? && zip_changed?
      # TODO join on zip
      district = District.from_zip(zip)
      self.district = district if district.present?
    end
  end
end
