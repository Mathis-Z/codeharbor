# frozen_string_literal: true

require 'digest'

class User < ApplicationRecord
  # Include devise modules. Others available are:
  # :timeoutable, :trackable
  devise :database_authenticatable,
         :confirmable,
         :lockable,
         :omniauthable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable

  groupify :named_group_member
  groupify :group_member

  validates :email, presence: true, uniqueness: {case_sensitive: false}
  validates :first_name, :last_name, presence: true

  has_many :tasks, dependent: :nullify

  has_many :collection_users, dependent: :destroy
  has_many :collections, through: :collection_users

  has_many :account_link_users, dependent: :destroy
  has_many :shared_account_links, through: :account_link_users, dependent: :destroy, source: :account_link

  has_many :reports, dependent: :destroy
  has_many :account_links, dependent: :destroy

  has_many :sent_messages, class_name: 'Message', foreign_key: 'sender_id', dependent: :nullify, inverse_of: :sender
  has_many :received_messages, class_name: 'Message', foreign_key: 'recipient_id', dependent: :nullify, inverse_of: :recipient

  has_one_attached :avatar
  validate :avatar_format, if: -> { avatar.attached? }

  default_scope { where(deleted: [nil, false]) }

  # Called by Devise and overwritten for soft-deletion
  def destroy
    return false unless handle_destroy

    self.attributes = {
      first_name: 'deleted',
      last_name: 'user',
      email: Digest::MD5.hexdigest(email),
      deleted: true
    }

    skip_reconfirmation!
    skip_email_changed_notification!
    save!(validate: false)
  end

  def member_groups
    groups - groups.as(:pending)
  end

  def name
    "#{first_name} #{last_name}"
  end

  def handle_destroy
    destroy = handle_group_memberships
    if destroy
      handle_collection_membership
      handle_messages
      true
    else
      false
    end
  end

  def handle_group_memberships
    # in_all_groups?(as: 'admin')

    groups.each do |group|
      if group.users.size > 1
        return false if in_group?(group, as: 'admin') && group.admins.size == 1
      else
        group.destroy
      end
    end
    true
  end

  def handle_collection_membership
    collections.each do |collection|
      collection.delete if collection.users.count == 1
    end
  end

  def handle_messages
    Message.where(sender: self, param_type: %w[group collection]).destroy_all
  end

  def unread_messages_count
    Message.where(recipient: self, recipient_status: 'u').count.to_s
  end

  def available_account_links
    account_links + shared_account_links
  end

  private

  def avatar_format
    avatar_blob = avatar.blob
    if avatar_blob.content_type.start_with? 'image/'
      errors.add(:avatar, 'size needs to be less than 10MB') if avatar_blob.byte_size > 10.megabytes
    else
      errors.add(:avatar, 'needs to be an image')
    end
  end
end
