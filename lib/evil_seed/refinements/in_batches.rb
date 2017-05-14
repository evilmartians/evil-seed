require 'active_record/relation/batches'

module EvilSeed
  module Refinements
    # This backports ActiveRecord::Relation#in_batches method for ActiveRecord 4.2
    # This module contains this method and +BatchEnumerator+ class picked from Ruby on Rails codebase at 2017-05-14
    # See https://github.com/rails/rails/commit/25cee1f0373aa3b1d893413a959375480e0ac684
    # The ActiveRecord MIT license is obviously compatible with our license (MIT also)
    module InBatches
      refine ActiveRecord::Relation do

        # This is from active_record/core
        def arel_attribute(name, table = klass.arel_table) # :nodoc:
          name = klass.attribute_alias(name) if klass.attribute_alias?(name)
          table[name]
        end

        class BatchEnumerator
          include Enumerable

          def initialize(of: 1000, start: nil, finish: nil, relation:) #:nodoc:
            @of       = of
            @relation = relation
            @start = start
            @finish = finish
          end

          # Looping through a collection of records from the database (using the
          # +all+ method, for example) is very inefficient since it will try to
          # instantiate all the objects at once.
          #
          # In that case, batch processing methods allow you to work with the
          # records in batches, thereby greatly reducing memory consumption.
          #
          #   Person.in_batches.each_record do |person|
          #     person.do_awesome_stuff
          #   end
          #
          #   Person.where("age > 21").in_batches(of: 10).each_record do |person|
          #     person.party_all_night!
          #   end
          #
          # If you do not provide a block to #each_record, it will return an Enumerator
          # for chaining with other methods:
          #
          #   Person.in_batches.each_record.with_index do |person, index|
          #     person.award_trophy(index + 1)
          #   end
          def each_record
            return to_enum(:each_record) unless block_given?

            @relation.to_enum(:in_batches, of: @of, start: @start, finish: @finish, load: true).each do |relation|
              relation.records.each { |record| yield record }
            end
          end

          # Delegates #delete_all, #update_all, #destroy_all methods to each batch.
          #
          #   People.in_batches.delete_all
          #   People.where('age < 10').in_batches.destroy_all
          #   People.in_batches.update_all('age = age + 1')
          [:delete_all, :update_all, :destroy_all].each do |method|
            define_method(method) do |*args, &block|
              @relation.to_enum(:in_batches, of: @of, start: @start, finish: @finish, load: false).each do |relation|
                relation.send(method, *args, &block)
              end
            end
          end

          # Yields an ActiveRecord::Relation object for each batch of records.
          #
          #   Person.in_batches.each do |relation|
          #     relation.update_all(awesome: true)
          #   end
          def each
            enum = @relation.to_enum(:in_batches, of: @of, start: @start, finish: @finish, load: false)
            return enum.each { |relation| yield relation } if block_given?
            enum
          end
        end

        # Yields ActiveRecord::Relation objects to work with a batch of records.
        #
        #   Person.where("age > 21").in_batches do |relation|
        #     relation.delete_all
        #     sleep(10) # Throttle the delete queries
        #   end
        #
        # If you do not provide a block to #in_batches, it will return a
        # BatchEnumerator which is enumerable.
        #
        #   Person.in_batches.with_index do |relation, batch_index|
        #     puts "Processing relation ##{batch_index}"
        #     relation.each { |relation| relation.delete_all }
        #   end
        #
        # Examples of calling methods on the returned BatchEnumerator object:
        #
        #   Person.in_batches.delete_all
        #   Person.in_batches.update_all(awesome: true)
        #   Person.in_batches.each_record(&:party_all_night!)
        #
        # ==== Options
        # * <tt>:of</tt> - Specifies the size of the batch. Default to 1000.
        # * <tt>:load</tt> - Specifies if the relation should be loaded. Default to false.
        # * <tt>:start</tt> - Specifies the primary key value to start from, inclusive of the value.
        # * <tt>:finish</tt> - Specifies the primary key value to end at, inclusive of the value.
        # * <tt>:error_on_ignore</tt> - Overrides the application config to specify if an error should be raised when
        #                               an order is present in the relation.
        #
        # Limits are honored, and if present there is no requirement for the batch
        # size, it can be less than, equal, or greater than the limit.
        #
        # The options +start+ and +finish+ are especially useful if you want
        # multiple workers dealing with the same processing queue. You can make
        # worker 1 handle all the records between id 1 and 9999 and worker 2
        # handle from 10000 and beyond by setting the +:start+ and +:finish+
        # option on each worker.
        #
        #   # Let's process from record 10_000 on.
        #   Person.in_batches(start: 10_000).update_all(awesome: true)
        #
        # An example of calling where query method on the relation:
        #
        #   Person.in_batches.each do |relation|
        #     relation.update_all('age = age + 1')
        #     relation.where('age > 21').update_all(should_party: true)
        #     relation.where('age <= 21').delete_all
        #   end
        #
        # NOTE: If you are going to iterate through each record, you should call
        # #each_record on the yielded BatchEnumerator:
        #
        #   Person.in_batches.each_record(&:party_all_night!)
        #
        # NOTE: It's not possible to set the order. That is automatically set to
        # ascending on the primary key ("id ASC") to make the batch ordering
        # consistent. Therefore the primary key must be orderable, e.g an integer
        # or a string.
        #
        # NOTE: By its nature, batch processing is subject to race conditions if
        # other processes are modifying the database.
        def in_batches(of: 1000, start: nil, finish: nil, load: false, error_on_ignore: nil)
          relation = self
          unless block_given?
            return BatchEnumerator.new(of: of, start: start, finish: finish, relation: self)
          end

          if arel.orders.present?
            act_on_ignored_order(error_on_ignore)
          end

          batch_limit = of
          if limit_value
            remaining   = limit_value
            batch_limit = remaining if remaining < batch_limit
          end

          relation = relation.reorder(batch_order).limit(batch_limit)
          relation = apply_limits(relation, start, finish)
          batch_relation = relation

          loop do
            if load
              records = batch_relation.records
              ids = records.map(&:id)
              yielded_relation = where(primary_key => ids)
              yielded_relation.load_records(records)
            else
              ids = batch_relation.pluck(primary_key)
              yielded_relation = where(primary_key => ids)
            end

            break if ids.empty?

            primary_key_offset = ids.last
            raise ArgumentError.new("Primary key not included in the custom select clause") unless primary_key_offset

            yield yielded_relation

            break if ids.length < batch_limit

            if limit_value
              remaining -= ids.length

              if remaining == 0
                # Saves a useless iteration when the limit is a multiple of the
                # batch size.
                break
              elsif remaining < batch_limit
                relation = relation.limit(remaining)
              end
            end

            batch_relation = relation.where(arel_attribute(primary_key).gt(primary_key_offset))
          end
        end

        private

        def apply_limits(relation, start, finish)
          relation = relation.where(arel_attribute(primary_key).gteq(start)) if start
          relation = relation.where(arel_attribute(primary_key).lteq(finish)) if finish
          relation
        end

        def batch_order
          "#{quoted_table_name}.#{quoted_primary_key} ASC"
        end

        def act_on_ignored_order(error_on_ignore)
          raise_error = (error_on_ignore.nil? ? klass.error_on_ignored_order : error_on_ignore)

          if raise_error
            raise ArgumentError.new(ORDER_IGNORE_MESSAGE)
          elsif logger
            logger.warn(ORDER_IGNORE_MESSAGE)
          end
        end
      end
    end
  end
end
