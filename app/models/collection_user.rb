# frozen_string_literal: true

class CollectionUser < ApplicationRecord
  belongs_to :collection
  belongs_to :user

  validates :user_id, uniqueness: {scope: :collection_id}
end
