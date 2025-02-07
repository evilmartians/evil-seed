# frozen_string_literal: true

forums = Forum.create!([{ name: 'One' }, { name: 'Two' }])
Forum.create!(name: 'Descendant forum', parent: forums.first)

roles = Role.create!(
  [
    { name: 'Superadmin', permissions: %w[do_everything do_nothing]        },
    { name: 'User',       permissions: %w[create_questions create_answers] },
    { name: 'Nobody',     permissions: %w[do_nothing]                      },
    { name: 'UFO',        permissions: %w[delete_everything]               },
  ],
)

users = User.create!(
  [
    { login: 'johndoe', email: 'johndoe@example.com', password: 'realhash', forum: forums[0], roles: [roles.second] },
    { login: 'janedoe', email: 'janedoe@example.net', password: 'realhash', forum: forums[1], roles: [roles.first]  },
    { login: 'alice',   email: 'alice@yahoo.com',     password: 'realhash', forum: forums[0], roles: [roles.second] },
    { login: 'bob',     email: 'robert1998@mail.ru',  password: 'realhash', forum: forums[0], roles: [roles.third]  },
    { login: 'charlie', email: 'charlie@gmail.com',   password: 'realhash', forum: forums[0], roles: [roles.last]   },
    { login: 'eva',     email: 'eva@evil.com',        password: 'realhash', forum: forums[0], roles: [roles.third]  },
  ],
)

question = forums.first.questions.create!(
  name:   'What to do if I want to do strange things with ActiveRecord?',
  text:   'Very strange things',
  rating: 10,
  author: User.find_by!(login: 'johndoe'),
)

question.votes.create!(user: User.find_by!(login: 'alice'))

answer = question.answers.create!(
  text:   'Oh please go on hack it, ROFL)))',
  best:   true,
  author: User.find_by!(login: 'alice'),
)

answer.reactions.create!(users.map.with_index do |user, i|
  { user: user, reaction: ':+1:', created_at: Time.current - 1.hour + i.minutes }
end)

answer = question.answers.create!(
  text:   'Please, stop',
  author: User.find_by!(login: 'bob'),
)

answer = question.answers.create!(
  text:   'Oops, I was wrong',
  author: User.find_by!(login: 'eva'),
  deleted_at: Time.current,
)

answer.votes.create!(user: User.find_by!(login: 'eva'))

question_attrs = %w[first second third fourth fifth].map { |name| { name: name, forum: forums.first } }
Question.create!(question_attrs)

Profile.create!([
  { user: users[0], default: true,  name: "Default profile for user 0", title: "Default title for user 0" },
  { user: users[0], default: false, name: "Profile for user 0", title: "Title for user 0" },
  { user: users[1], default: true,  name: "Profile for user 1", title: "Title for user 1" },
  { user: users[2], default: true,  name: "Profile for user 2", title: "Title for user 2" },
])

Version.create!([
  { id: 1},
  { id: 2},
])