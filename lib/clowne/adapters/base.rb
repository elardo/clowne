# frozen_string_literal: true

require 'clowne/adapters/registry'

require 'clowne/resolvers/init_as'
require 'clowne/resolvers/nullify'
require 'clowne/resolvers/finalize'
require 'clowne/resolvers/after_persist'

module Clowne
  module Adapters
    # ORM-independant adapter (just calls #dup).
    # Works with nullify/finalize.
    class Base
      include Clowne::Adapters::Registry::Container

      class << self
        # Duplicate record and remember record <-> clone relationship in operation
        # +record+:: Instance of record (ActiveRecord or Sequel)
        def dup_record(record)
          raw_dup_record(record).tap do |clone|
            operation = operation_class.current
            operation.add_mapping(record, clone)
          end
        end

         # Base method to make a duplicate of record
         # Cab be overrided in special adapter
         # +record+:: Instance of record (ActiveRecord or Sequel)
        def raw_dup_record(record)
          record.dup
        end

        # Operation class which  using for cloning
        # Cab be overrided in special adapter
        def operation_class
          Clowne::Utils::Operation
        end
      end

      # Using a plan make full duplicate of record
      # +source+:: Instance of cloned object (ex: User.new(posts: posts))
      # +plan+:: Array of Declarations
      # +params+:: Custom params hash
      def clone(source, plan, params: {})
        declarations = plan.declarations
        declarations.inject(init_record(self.class.dup_record(source))) do |record, (type, declaration)|
          resolver_for(type).call(source, record, declaration, params: params, adapter: self)
        end
      end

      def init_record(record)
        # Override in custom adapters
        record
      end
    end
  end
end

Clowne::Adapters::Base.register_resolver(
  :init_as,
  Clowne::Resolvers::InitAs,
  prepend: true
)

Clowne::Adapters::Base.register_resolver(
  :nullify,
  Clowne::Resolvers::Nullify
)

Clowne::Adapters::Base.register_resolver(
  :finalize, Clowne::Resolvers::Finalize,
  after: :nullify
)

Clowne::Adapters::Base.register_resolver(
  :after_persist, Clowne::Resolvers::AfterPersist,
  after: :finalize
)
