class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  has_many :migraines, dependent: :destroy
  has_many :medications, dependent: :destroy

  scope :admins, -> { where(admin: true) }

  after_create :ensure_default_medications

  private

  def ensure_default_medications
    %w[Ibuprofen Triptan].each do |name|
      medications.find_or_create_by(name: name)
    end
  end
end
