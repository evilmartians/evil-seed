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

User.create!(
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

question.answers.create!(
  text:   'Oh please go on hack it, ROFL)))',
  best:   true,
  author: User.find_by!(login: 'alice'),
)

answer = question.answers.create!(
  text:   'Please, stop',
  author: User.find_by!(login: 'bob'),
)

answer.votes.create!(user: User.find_by!(login: 'eva'))

question_attrs = %w[first second third fourth fifth].map { |name| { name: name, forum: forums.first } }
Question.create!(question_attrs)
