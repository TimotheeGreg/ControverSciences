class User < ApplicationRecord

  extend FriendlyId
  friendly_id :name, use: [:slugged, :finders]

  include PgSearch::Model
  pg_search_scope :search_by_name,
                  :against => [:name],
                  :ignoring => :accents,
                  :using => {
                      :tsearch => {},
                      :trigram => {}
                  }

  has_many :timelines, dependent: :destroy
  has_many :references, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :summaries, dependent: :destroy
  has_many :links, dependent: :destroy
  has_many :summary_links, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :credits, dependent: :destroy
  has_many :timeline_contributors, dependent: :destroy
  has_many :reference_contributors, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :notification_selections, dependent: :destroy
  has_many :visite_references, dependent: :destroy
  has_many :visite_timelines, dependent: :destroy
  has_many :go_patches, dependent: :destroy
  has_many :received_patches, class_name: "GoPatch", foreign_key: "target_user_id", dependent: :destroy
  has_many :frames, dependent: :destroy
  has_many :frame_credits, dependent: :destroy
  has_many :edges, dependent: :destroy
  has_many :edge_votes, dependent: :destroy
  has_many :reference_edges, dependent: :destroy
  has_many :reference_edge_votes, dependent: :destroy
  has_many :reference_user_tags, dependent: :destroy
  has_one :user_detail, dependent: :destroy
  has_one :pending_user, dependent: :destroy
  has_one :user_detail, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :figures, dependent: :destroy
  has_many :binaries, dependent: :destroy
  has_many :dead_links, dependent: :destroy
  has_many :private_timelines, dependent: :destroy
  has_many :timeline_choices, dependent: :destroy
  has_many :patch_messages, dependent: :destroy
  has_many :user_patches, dependent: :destroy

  attr_accessor :remember_token, :activation_token, :reset_token, :why,
                :invalid_email, :terms_of_service, :invited, :timelines_count,
                :empty_references, :empty_comments, :empty_summaries, :admin_patches,
                :notif_patches, :admin_dead_links, :admin_pending_users, :pending_patches
  before_save :transliterate_email
  before_create :create_activation_digest

  validates_acceptance_of :terms_of_service
  validates :name, presence: true, length: {maximum: 50}
  validates :email, presence: true,
            :email => true,
            uniqueness: {case_sensitive: false}
  has_secure_password
  validates :password, length: {minimum: 6}, allow_blank: true
  validate :email_domain

  def email_domain
    #mydomain = self.email.partition("@")[2]
    if self.activated?
      return true
    end
    #Domain.all.pluck(:name).each do |domain|
    #  if mydomain.include? domain
    #    return true
    #  end
    #end
    if self.why.blank?
      return true
    #  errors.add(:email, 'appartient à un domaine non connu.
    #      Veuillez donner des informations complémentaires.')
    else
      self.invalid_email = true
    end
  end

  # Returns the hash digest of the given string.
  def User.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
        BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
  end

  # Returns a random token.
  def User.new_token
    SecureRandom.urlsafe_base64
  end

  # Remembers a user in the database for use in persistent sessions.
  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end

  # Returns true if the given token matches the digest.
  def authenticated?(attribute, token)
    digest = send("#{attribute}_digest")
    digest.present? ? BCrypt::Password.new(digest).is_password?(token) : false
  end

  def forget
    update_attribute(:remember_digest, nil)
  end


  # Sets the password reset attributes.
  def create_reset_digest
    self.reset_token = User.new_token
    update_attribute(:reset_digest, User.digest(reset_token))
    update_attribute(:reset_sent_at, Time.zone.now)
  end

  # Activates an account.
  def activate
    update_attribute(:activated, true)
    update_attribute(:activated_at, Time.zone.now)
  end

  # Returns true if a password reset has expired.
  def password_reset_expired?
    reset_sent_at < 15.days.ago
  end

  def notifications_model(category)
    Notification.where(user_id: self.id, category: category).count
  end

  def notifications_all
    Notification.where(user_id: self.id).count
  end

  def notifications_count
    notifications_all + notif_patches + nb_notifs + pending_patches +
        admin_patches + admin_dead_links + admin_pending_users + invited
  end

  # Creates and assigns the activation token and digest.
  def create_activation_digest
    self.activation_token = User.new_token
    self.activation_digest = User.digest(activation_token)
  end

  def anon_and_destroy
    anon_id = User.find_by(email: "contact@controversciences.org").id
    Reference.where(:user_id => self.id).update_all(user_id: anon_id)
    Timeline.where(:user_id => self.id).update_all(user_id: anon_id)
    Comment.where(user_id: self.id).map(&:destroy_with_counters)
    Frame.where(user_id: self.id).map(&:destroy_with_counters)
    Summary.where(user_id: self.id).map(&:destroy_with_counters)
    self.destroy
  end

  private

  # Converts email to all lower-case.
  def transliterate_email
    self.email = email.transliterate
  end
end
