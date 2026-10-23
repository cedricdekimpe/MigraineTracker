class EpisodeTrigger < ApplicationRecord
  belongs_to :episode
  belongs_to :trigger

  validates :trigger_id, uniqueness: { scope: :episode_id }
end
