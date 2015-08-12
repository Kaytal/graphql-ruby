# These are valid values for a type's `fields` hash.
#
# You can also use {FieldDefiner#build} to create fields.
#
# @example creating a field
#   name_field = GraphQL::Field.new do |f, types|
#     f.name("Name")
#     f.type(!types.String)
#     f.description("The name of this thing")
#     f.resolve -> (object, arguments, context) { object.name }
#   end
#
class GraphQL::Field
  DEFAULT_RESOLVE = -> (o, a, c) { GraphQL::Query::DEFAULT_RESOLVE }
  extend GraphQL::DefinitionHelpers::Definable
  include GraphQL::DefinitionHelpers::DefinedByConfig
  attr_definable(:arguments, :deprecation_reason, :name, :description, :type)

  class DefinitionConfig
    extend GraphQL::DefinitionHelpers::Definable
    attr_definable :name, :description, :type, :deprecation_reason, :resolve
    def initialize
      @arguments = {}
    end

    def types
      GraphQL::DefinitionHelpers::TypeDefiner.instance
    end

    def argument(name, type)
      # todo: support description & deprecation
      @arguments[name.to_s] = GraphQL::Argument.new(name: name.to_s, type: type)
    end

    def to_instance
      object = GraphQL::Field.new
      object.name = name
      object.type = type
      object.description = description
      object.deprecation_reason = deprecation_reason
      object.resolve = resolve
      object.arguments = @arguments
      object
    end
  end

  def initialize
    @arguments = {}
    @resolve_proc = DEFAULT_RESOLVE
    if block_given?
      yield(
        self,
        GraphQL::DefinitionHelpers::TypeDefiner.instance,
        GraphQL::DefinitionHelpers::FieldDefiner.instance,
        GraphQL::DefinitionHelpers::ArgumentDefiner.instance
      )
      warn("Initializing with .new is deprecated, use .define instead! (see #{self})")
    end
  end

  def arguments(new_arguments=nil)
    if !new_arguments.nil?
      self.arguments=(new_arguments)
    end
    @arguments
  end

  # Define the arguments for this field using {StringNamedHash}
  def arguments=(new_arguments)
    @arguments = GraphQL::DefinitionHelpers::StringNamedHash.new(new_arguments).to_h
  end

  # @overload resolve(definition_proc)
  #   Define this field to return a value with `definition_proc`
  #   @example defining the resolve method
  #     field.resolve -> (obj, args, ctx) { obj.get_value }
  #   @param definition_proc [Proc] The proc to evaluate to get a value
  #
  # @overload resolve(object, arguments, context)
  #   Get a value for this field
  #   @example resolving a field value
  #     field.resolve(obj, args, ctx)
  #
  #   @param object [Object] The object this field belongs to
  #   @param arguments [Hash] Arguments declared in the query
  #   @param context [GraphQL::Query::Context]
  def resolve(proc_or_object, arguments=nil, context=nil)
    if arguments.nil? && context.nil?
      @resolve_proc = proc_or_object
    else
      @resolve_proc.call(proc_or_object, arguments, context)
    end
  end

  def resolve=(resolve_proc)
    @resolve_proc = resolve_proc || DEFAULT_RESOLVE
  end

  # @overload type(return_type)
  #   Define the return type for this field
  #   @param return_type [GraphQL::ObjectType, GraphQL::ScalarType] The type this field returns
  #
  # @overload type(return_type_proc)
  #   Wrap the return type in a proc,which will cause the type to be lazy-evaled,
  #
  #   That's nice if you have load-order issues.
  #   @example lazy-evaled return type
  #      field.type(-> { MyCircularDependentType })
  #   @param return_type_proc [Proc] A proc which returns the return type for this field
  def type(type_or_proc=nil)
    if !type_or_proc.nil?
      @type = type_or_proc
    elsif @type.is_a?(Proc)
      # lazy-eval it
      @type = @type.call
    end
    @type
  end

  def to_s
    "<Field: #{name || "not-named"}>"
  end
end
