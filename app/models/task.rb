# frozen_string_literal: true

require 'nokogiri'
require 'zip'
class Task < ApplicationRecord
  acts_as_taggable_on :state

  groupify :group_member
  validates :title, presence: true

  validates :uuid, uniqueness: true

  has_many :files, as: :fileable, class_name: 'TaskFile', dependent: :destroy

  has_many :tests, dependent: :destroy
  has_many :model_solutions, dependent: :destroy

  # has_many :collection_tasks, dependent: :destroy
  # has_many :collections, through: :collection_tasks

  has_many :comments, dependent: :destroy
  has_many :ratings, dependent: :destroy

  belongs_to :user
  belongs_to :programming_language, optional: true

  accepts_nested_attributes_for :files, allow_destroy: true
  accepts_nested_attributes_for :tests, allow_destroy: true
  accepts_nested_attributes_for :model_solutions, allow_destroy: true

  scope :not_owner, ->(user) { where.not(user: user) }
  scope :owner, ->(user) { where(user: user) }
  scope :visibility, ->(visibility, user = nil) { {owner: owner(user), public: not_owner(user)}.with_indifferent_access[visibility] }
  scope :created_before_days, ->(days) { where(created_at: days.to_i.days.ago.beginning_of_day..) if days.to_i.positive? }
  scope :min_stars, lambda { |stars|
                      joins('LEFT JOIN (SELECT task_id, AVG(rating) AS avg_rating FROM ratings GROUP BY task_id)
                             AS ratings ON ratings.task_id = tasks.id')
                        .where('COALESCE(avg_rating, 0) >= ?', stars)
                    }

  serialize :meta_data, HashAsJsonbSerializer

  def self.ransackable_scopes(_auth_object = nil)
    %i[created_before_days min_stars]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[title description programming_language_id created_at]
  end

  def can_access(user)
    self.user == user
  end

  def duplicate
    dup.tap do |task|
      task.uuid = nil
      task.tests = duplicate_tests
      task.files = duplicate_files
      task.model_solutions = duplicate_model_solutions
    end
  end

  def initialize_derivate(user = nil)
    duplicate.tap do |task|
      task.user = user if user
    end
  end

  def average_rating
    if ratings.empty?
      0
    else
      ratings.map(&:rating).sum.to_f / ratings.size
    end
  end

  def rating_star
    (average_rating * 2).round / 2.0
  end

  private

  def duplicate_tests
    tests.map(&:duplicate)
  end

  def duplicate_files
    files.map(&:duplicate)
  end

  def duplicate_model_solutions
    model_solutions.map(&:duplicate)
  end
end
