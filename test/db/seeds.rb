# frozen_string_literal: true

forums = Forum.create!([{ name: 'One' }, { name: 'Two' }])
Forum.create!(name: 'Descendant forum', parent: forums.first)

User.create!([{ login: 'johndoe', forum: forums.first }, { login: 'janedoe', forum: forums.last }])
