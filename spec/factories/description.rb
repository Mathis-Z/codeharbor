# frozen_string_literal: true

FactoryBot.define do
  factory :description, aliases: [:simple_description], class: 'Description' do
    sequence(:text) { |n| "Very descriptive #{n}" }
    language { 'en' }

    trait(:primary) do
      primary { true }
    end
  end

  factory :codeharbor_description, class: 'Description' do
    text { 'This is a test-exercise for export to codeharbor. All important fields are set. Replace the x with the right word.' }
    language { 'en' }
  end
end
