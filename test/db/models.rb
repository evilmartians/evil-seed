# frozen_string_literal: true

class User < ActiveRecord::Base
  has_one :profile
  belongs_to :forum

  has_many :questions
  has_many :answers
  has_many :votes

  has_and_belongs_to_many :roles
end

class Role < ActiveRecord::Base
  has_and_belongs_to_many :users
end

class Forum < ActiveRecord::Base
  has_many :questions

  has_many :popular_questions, -> { order(rating: :desc).limit(10) }, class_name: 'Question'

  has_many :tracking_pixels

  belongs_to :author, class_name: 'User'
end

class Question < ActiveRecord::Base
  belongs_to :author, class_name: 'User'

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

class Vote < ActiveRecord::Base
  belongs_to :votable, polymorphic: true
  belongs_to :user
end
