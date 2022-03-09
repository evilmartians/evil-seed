# frozen_string_literal: true

class User < ActiveRecord::Base
  has_one :profile
  belongs_to :forum

  has_many :questions, foreign_key: :author_id
  has_many :answers,   foreign_key: :author_id
  has_many :votes

  has_and_belongs_to_many :roles, join_table: :user_roles
end

class Profile < ActiveRecord::Base
  belongs_to :user

  attribute :virtual, :string
end

class Role < ActiveRecord::Base
  has_and_belongs_to_many :users, join_table: :user_roles
end

class Forum < ActiveRecord::Base
  belongs_to :parent, class_name: 'Forum', inverse_of: :children
  has_many :children, class_name: 'Forum', inverse_of: :parent, foreign_key: :parent_id

  has_many :questions
  has_many :popular_questions, -> { order(rating: :desc).limit(10) }, class_name: 'Question'
  has_many :tracking_pixels
  has_many :users
end

class Question < ActiveRecord::Base
  belongs_to :author, class_name: 'User'
  belongs_to :forum

  has_many :answers
  has_many :votes, as: :votable

  has_many :voters, through: :votes, source: :user

  has_one :best_answer, -> { where(best: true) }, class_name: 'Answer'
end

class Answer < ActiveRecord::Base
  belongs_to :author, class_name: 'User'

  has_many :votes, as: :votable

  has_many :voters, through: :votes, source: :user
end

class TrackingPixel < ActiveRecord::Base
  belongs_to :forum
end

class Vote < ActiveRecord::Base
  belongs_to :votable, polymorphic: true
  belongs_to :user
end
